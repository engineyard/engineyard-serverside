require 'engineyard-serverside/dependency_manager/base'

module EY
  module Serverside
    class DependencyManager
      class Mix < Base

        def detected?
          gemfile?
        end

        def gemfile?
          paths.gemfile.exist?
        end

        def check
          if lockfile
            shell.status "Mix.exs and Mix.lock found"

          elsif ! config.ignore_gemfile_lock_warning
            shell.warning <<-WARN
Mixfile found but mix.lock is missing!
You can get different versions of hex packages in production than what you tested with.
You can get different versions of hex packages on every deployment even if your mix file hasn't changed.
Deploying will take longer and some deploy options will be limited.

To fix this problem, commit your mix.lock to your repository and redeploy.
            WARN
          end
        end

        def install
          shell.status "Bundling gems..."
          clean_bundle_on_system_version_change
          install_bundler_gem
          run "#{clean_environment} && cd #{paths.active_release} && #{bundle_install_command}"
          write_system_version
        end

        protected

        def write_system_version
          store_ruby_version   = "#{config.ruby_version_command} > #{paths.ruby_version}"
          store_system_version = "#{config.system_version_command} > #{paths.system_version}"

          run "mkdir -p #{paths.bundled_gems} && chown #{config.user}:#{config.group} #{paths.bundled_gems}"
          run "#{store_ruby_version} && #{store_system_version}"
        end

        # Install bundler in the system ruby
        def install_bundler_gem
          egrep_escaped_version = bundler_version.gsub(/\./, '\.')
          # the grep "bundler " is so that gems like bundler08 don't get
          # their versions considered too
          #
          # the [,)] is to stop us from looking for e.g. 0.9.2, seeing
          # 0.9.22, and mistakenly thinking 0.9.2 is there
          has_gem_cmd = %{gem list bundler | grep "bundler " | egrep -q "#{egrep_escaped_version}[,)]"}
          install_cmd = %{gem install bundler -q --no-rdoc --no-ri -v "#{bundler_version}"}
          sudo "#{clean_environment} && #{has_gem_cmd} || #{install_cmd}"
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
          options += ["--deployment"] if lockfile
          options += config.extra_bundle_install_options
          options
        end

        def bundle_install_command
          "ruby -S bundle _#{bundler_version}_ install #{bundle_install_options.join(" ")}"
        end

        def bundler_version
          @bundler_version ||= lockfile && lockfile.bundler_version || self.class.default_version
        end

        def lockfile
          return @lockfile if defined? @lockfile

          lockfile_path = paths.gemfile_lock
          if lockfile_path.exist?
            @lockfile = Lockfile.new(lockfile_path.read, self.class.default_version)
          end
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

          def parse
            parse_from_metadata ||
              parse_from_dependencies ||
              raise("Malformed or pre bundler-1.0.0 Gemfile.lock: #{@contents[0,50]}...")
          end

          def slice_section(header)
            if start require 'engineyard-serverside/dependency_manager/base'
            end
