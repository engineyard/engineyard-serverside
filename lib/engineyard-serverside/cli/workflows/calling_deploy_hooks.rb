require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/deploy_hook'

module EY
  module Serverside
    module CLI
      module Workflows
        class CallingDeployHooks < Base
          private
          def procedure
            EY::Serverside::DeployHook.
              new(config, shell, hook_name).
              call

          end

          def task_name
            "hook-#{hook_name}"
          end

          def hook_name
            options[:hook_name]
          end
        end
      end
    end
  end
end
