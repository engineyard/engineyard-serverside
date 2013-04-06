require 'engineyard-serverside/dependency_manager/bundler'

module EY
  module Serverside
    module DependencyManager
      class BundlerLock < Bundler
        def detected?
          gemfile? && lockfile?
        end

        def check
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
        end

        def uses_sqlite3?
          lockfile.uses_sqlite3?
        end

        def check_ey_config
          unless lockfile.has_ey_config?
            shell.warning "Gemfile.lock does not contain ey_config.\nAdd gem 'ey_config' to get access to service configuration through EY::Config."
          end
        end

        def rails_version
          lockfile.rails_version
        end

        private

        def lockfile_path
          paths.gemfile_lock
        end

        def lockfile
          @lockfile ||= Lockfile.new(lockfile_path.read, self.class.default_version)
        end

        # deployment mode is not supported without a Gemfile.lock
        def bundle_install_options
          super + ["--deployment"]
        end

        def bundler_version
          @bundler_version ||= lockfile.bundler_version || super
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
