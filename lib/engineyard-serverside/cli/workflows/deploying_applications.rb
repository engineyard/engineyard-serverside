require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'

module EY
  module Serverside
    module CLI
      module Workflows

        # DeployingApplications is a Workflow that deploys the application
        # specified by the incoming options
        class DeployingApplications < Base
          include Helpers

          private
          def procedure
            propagate_serverside

            deployer.deploy
          end

          def task_name
            'deploy'
          end
        end
      end
    end
  end
end
