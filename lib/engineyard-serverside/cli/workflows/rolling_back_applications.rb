require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'

module EY
  module Serverside
    module CLI
      module Workflows

        # RollingBackApplications is a Workflow that attempts to roll the
        # application specified in the options back to its previous deployment
        class RollingBackApplications < Base
          include Helpers

          private
          def procedure
            propagate_serverside

            deployer.rollback
          end

          def task_name
            'rollback'
          end
        end
      end
    end
  end
end
