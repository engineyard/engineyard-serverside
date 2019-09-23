require 'engineyard-serverside/callbacks/distributor/base'

module EY
  module Serverside
    module Callbacks
      module Distributor
        module Executable

          class Runnable < Base
            def distribute
              shell.status "Running deploy hook: #{hook}"

              runner.run [About.hook_executor, hook.callback_name].join(' ') do |server, cmd|
                cmd = hook_env_vars(server).
                  reject {|name,value| value.nil?}.
                  map {|name,value| "#{name}=#{Escape.shell_command([value])}"}.
                  join(' ') + ' ' + config.framework_envs + ' ' + cmd
              end
            end

            private
            def hook_env_vars(server)
              {
                'EY_DEPLOY_ACCOUNT_NAME' => config.account_name,
                'EY_DEPLOY_APP' => config.app,
                'EY_DEPLOY_CONFIG' => config.to_json,
                'EY_DEPLOY_CURRENT_ROLES' => server.roles.to_a.join(' '),
                'EY_DEPLOY_CURRENT_NAME' => server.name ? server.name.to_s : nil,
                'EY_DEPLOY_ENVIRONMENT_NAME' => config.environment_name,
                'EY_DEPLOY_FRAMEWORK_ENV' => config.framework_env.to_s,
                'EY_DEPLOY_RELEASE_PATH' => paths.active_release.to_s,
                'EY_DEPLOY_VERBOSE' => (config.verbose ? '1' : '0'),
              }
            end
          end

        end
      end
    end
  end
end
