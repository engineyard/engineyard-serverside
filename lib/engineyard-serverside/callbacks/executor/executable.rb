require 'escape'
require 'runner'
require 'engineyard-serverside/callbacks/executor/base'

module EY
  module Serverside
    module Callbacks
      module Executor

        class Executable < Base
          include Runner

          step :validate_hook
          step :populate_environment
          step :calculate_wrapper
          step :run_hook

          def handle_failure(payload = {})
            case payload[:reason]

            when :not_executable
              true
            when :execution_failed
              abort "*** [Error] Hook failed to exit cleanly: #{hook_path} ***\n"
            else
              abort "*** [Error] An unknown error occurred for hook: #{hook_path} ***\n"
            end
          end

          def validate_hook(input = {})
            unless hook_path.executable?
              shell.warning("Skipping possible deploy hook #{hook} because it is not executable.")

              return Failure(
                input.merge(
                  {
                    :reason => :not_executable
                  }
                )
              )
            end

            Success(input)
          end

          def calculate_wrapper(input = {})
            Success(
              input.merge(
                {
                  :wrapper => hook.respond_to?(:service_name) ?
                    About.service_hook_executor :
                    About.hook_executor
                }
              )
            )
          end

          def run_hook(input = {})
            env = "#{input[:environment]} #{config.framework_envs}"
            wrapper = input[:wrapper]
            name = hook.short_name

            result = run("#{env} #{wrapper} #{name}")

            unless result.success?
              return Failure(
                input.merge(
                  {
                    :reason => :execution_failed
                  }
                )
              )
            end

            Success(input)
          end

          def populate_environment(input = {})
            env = {
              'EY_DEPLOY_ACCOUNT_NAME' => config.account_name,
              'EY_DEPLOY_APP' => config.app,
              'EY_DEPLOY_CONFIG' => config.to_json,
              'EY_DEPLOY_CURRENT_ROLES' => current_roles,
              'EY_DEPLOY_CURRENT_NAME' => current_name,
              'EY_DEPLOY_ENVIRONMENT_NAME' => config.environment_name,
              'EY_DEPLOY_FRAMEWORK_ENV' => config.framework_env.to_s,
              'EY_DEPLOY_RELEASE_PATH' => paths.active_release.to_s,
              'EY_DEPLOY_VERBOSE' => verbose,
            }

            Success(
              input.merge(
                {
                  :environment => env.
                    reject {|name, value| value.nil?}.
                    map {|name, value| "#{name}=#{Escape.shell_command([value])}"}.
                    join(' ')
                }
              )
            )
          end

          def verbose
            config.verbose ? '1' : '0'
          end

          def current_roles
            config.current_roles.to_a.join(' ')
          end

          def current_name
            name = config.current_name

            unless name
              return nil
            end

            name.to_s
          end
        end

      end
    end
  end
end
