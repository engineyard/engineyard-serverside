module EY
  module Serverside
    class DependencyManager
      class Base
        attr_reader :servers, :config, :shell, :runner

        def initialize(servers, config, shell, runner)
          @servers, @config, @shell, @runner = servers, config, shell, runner
        end

        # Public interface
        #
        def detected?() false end
        def check() end
        def install() end
        def uses_sqlite3?() end
        def rails_version() end
        def show_ey_config_instructions() end

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
