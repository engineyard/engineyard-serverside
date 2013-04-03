module EY
  module Serverside
    module DependencyManager
      class Bundler < Base
        DEFAULT_VERSION = "1.3.4"

        def self.default_version
          DEFAULT_VERSION
        end

        def detected?
          paths.gemfile.exist?
        end
        alias gemfile? detected?

        def check
          if lockfile
            shell.status "Gemfile and Gemfile.lock found"

            if config.check_database_adapter? && !lockfile.any_database_adapter?
              shell.warning <<-WARN
Gemfile.lock does not contain a recognized database adapter.
A database-adapter gem such as pg, mysql2, mysql, or do_mysql was expected.
This can prevent applications that use PostgreSQL or MySQL from booting.

To fix, add any needed adapter to your Gemfile, bundle, commit, and redeploy.
Applications not using PostgreSQL or MySQL can safely ignore this warning by
adding ignore_database_adapter_warning: true to the application's ey.yml file
under this environment's name and adding the file to your repository.
              WARN
            end

          else
            shell.warning <<-WARN
Gemfile found but Gemfile.lock is missing!
You can get different versions of gems in production than what you tested with.
You can get different versions of gems on every deployment even if your Gemfile hasn't changed.
Deploying will take longer.

To fix this problem, commit your Gemfile.lock to your repository and redeploy.
            WARN
          end
        end

        def install
          check_ruby_bundler
        end

        def uses_sqlite3?
          lockfile && lockfile.uses_sqlite3?
        end

        def check_ey_config
          if lockfile && !lockfile.has_ey_config?
            shell.warning "Gemfile.lock does not contain ey_config.\nAdd gem 'ey_config' to get access to service configuration through EY::Config."
          end
        end

        def rails_version
          lockfile && lockfile.rails_version
        end

        private

        def lockfile_path
          paths.gemfile_lock
        end

        def lockfile
          return @lockfile if defined? @lockfile
          @lockfile = lockfile_path.exist? ? Lockfile.new(lockfile_path.read, self.class.default_version) : nil
        end

        def write_system_version
          store_ruby_version   = "#{config.ruby_version_command} > #{paths.ruby_version}"
          store_system_version = "#{config.system_version_command} > #{paths.system_version}"

          run "mkdir -p #{paths.bundled_gems} && chown #{config.user}:#{config.group} #{paths.bundled_gems}"
          run "#{store_ruby_version} && #{store_system_version}"
        end

        def check_ruby_bundler
          shell.status "Bundling gems..."
          clean_bundle_on_system_version_change
          install_bundler_gem
          run "#{clean_environment} && cd #{paths.active_release} && #{bundle_install_command}"
          write_system_version
        end

        # Install bundler in the system ruby
        def install_bundler_gem
          egrep_escaped_version = bundler_version.gsub(/\./, '\.')
          # the grep "bundler " is so that gems like bundler08 don't get
          # their versions considered too
          #
          # the [,)] is to stop us from looking for e.g. 0.9.2, seeing
          # 0.9.22, and mistakenly thinking 0.9.2 is there
          clean_ruby  = %{unset RUBYOPT}
          has_gem_cmd = %{gem list bundler | grep "bundler " | egrep -q "#{egrep_escaped_version}[,)]"}
          install_cmd = %{gem install bundler -q --no-rdoc --no-ri -v "#{bundler_version}"}
          sudo "#{clean_ruby} && #{has_gem_cmd} || #{install_cmd}"
        end

        # GIT_SSH needs to be defined in the environment for customers with private bundler repos in their Gemfile.
        # It seems redundant to declare the env var again, but I'm hesitant to remove it right now.
        def clean_environment
          %{export GIT_SSH="#{ENV['GIT_SSH']}" && export LANG="en_US.UTF-8" && unset RUBYOPT BUNDLE_PATH BUNDLE_FROZEN BUNDLE_WITHOUT BUNDLE_BIN BUNDLE_GEMFILE}
        end

        def bundle_install_options
          options = [
            "--gemfile",  "#{paths.gemfile}",
            "--path",     "#{paths.bundled_gems}",
            "--binstubs", "#{paths.binstubs}",
          ]
          options << "--deployment" if lockfile # deployment mode is not supported without a Gemfile.lock
          options += config.extra_bundle_install_options
          options
        end

        def bundle_install_command
          "ruby -S bundle _#{bundler_version}_ install #{bundle_install_options.join(" ")}"
        end

        def clean_bundle_on_system_version_change
          # diff exits with 0 for same and 1/2 for different/file not found.
          check_ruby   = "#{config.ruby_version_command} | diff - #{paths.ruby_version} >/dev/null 2>&1"
          check_system = "#{config.system_version_command} | diff - #{paths.system_version} >/dev/null 2>&1"
          clean_bundle = "rm -Rf #{paths.bundled_gems}"

          shell.substatus "Checking for system version changes"
          run "#{check_ruby} && #{check_system} || #{clean_bundle}"
        end

        def bundler_version
          @bundler_version ||= lockfile ? lockfile.bundler_version : self.class.default_version
        end

        class Lockfile
          attr_reader :bundler_version

          def initialize(lockfile_contents, default = EY::Serverside::DependencyManager::Bundler.default_version)
            @contents = lockfile_contents
            @default = default
            @default_gem_version = Gem::Version.new(@default)
            parse
          end

          def has_ey_config?
            !!@contents.index(/^\s+ey_config\s\([^\)]+\)$/)
          end

          def rails_version
            section = dependencies_section
            if section.empty?
              return nil
            end
            result = scan_gem('rails', section)
            result ? result.last : nil
          end

          def any_database_adapter?
            any_ruby_adapter = %w[mysql2 mysql do_mysql pg do_postgres].any? do |type|
              @contents.index(/^\s+#{type}\s\([^\)]+\)$/)
            end

            any_jruby_adapter = %w[mysql postgresql postgres].any? do |type|
              @contents.index(/^\s+jdbc-#{type}\s\([^\)]+\)$/) || @contents.index(/^\s+activerecord-jdbc#{type}-adapter\s\([^\)]+\)$/)
            end

            any_ruby_adapter || any_jruby_adapter
          end

          def uses_sqlite3?
            !any_database_adapter? && @contents.index(/^\s+sqlite3\s\([^\)]+\)$/)
          end

          def parse
            parse_from_metadata ||
              parse_from_dependencies ||
              raise("Malformed or pre bundler-1.0.0 Gemfile.lock: #{@contents[0,50]}...")
          end

          def slice_section(header)
            if start = @contents.index(/^#{header}/)
              finish = @contents.index(/(^\S|\Z)/, start + header.length)
              @contents.slice(start..finish)
            else
              ""
            end
          end

          def parse_from_metadata
            section = slice_section('METADATA')

            if section.empty?
              return nil
            end

            result = section.scan(/^\s*version:\s*(.*)$/).first
            @bundler_version = result ? result.first : @default
          end

          def dependencies_section
            @dependencies_section ||= slice_section('DEPENDENCIES')
          end

          def parse_from_dependencies
            section = dependencies_section
            if section.empty?
              return nil
            end

            result = scan_gem('bundler', section)
            bundler_version = result ? result.last : nil
            version_qualifier = result ? result.first : nil
            @bundler_version = fetch_version(version_qualifier, bundler_version)
          end

          def fetch_version(operator, version)
            return version || @default unless operator && version
            req = Gem::Requirement.new(["#{operator} #{version}"])
            req.satisfied_by?(@default_gem_version) ? @default : version
          end

          def scan_gem(gem, dep_section)
            dep_section.scan(/^\s*#{Regexp.escape(gem)}\s*\((>?=|~>)\s*([^,\)]+)/).first
          end
        end
      end
    end
  end
end
