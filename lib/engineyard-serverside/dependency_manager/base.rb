module EY
  module Serverside
    module DependencyManager
      class Base
        def self.detect(servers, config, shell, runner)
          manager = new(servers, config, shell, runner)
          manager.detected? && manager
        end

        attr_reader :servers, :config, :shell, :runner

        def initialize(servers, config, shell, runner)
          @servers, @config, @shell = servers, config, shell
          @runner = runner
        end

        # Public interface
        #

        def detected?() true end
        def check() end
        def install() end

        # assume not using sqlite3 unless a dependency system says so
        def uses_sqlite3?() false end
        def rails_version() end
        def check_ey_config() end

        # Legacy methods, this should not be public API to this class
        # With proper warning, cut these methods off
        def gemfile?() end
        def bundler_config
          raise "This method has been removed. Use bundle_options in ey.yml"
        end
        def lockfile() end
        def check_ruby_bundler() end
        def check_node_npm() end
        def clean_bundle_on_system_version_change() end
        def write_system_version() end

        protected

        def paths
          config.paths
        end

        def on_roles
          [:app_master, :app, :solo, :util]
        end

        def run(cmd)
          runner.roles(on_roles) do
            runner.run(cmd)
          end
        end

        def sudo(cmd)
          runner.roles(on_roles) do
            runner.sudo(cmd)
          end
        end
      end
    end
  end
end
