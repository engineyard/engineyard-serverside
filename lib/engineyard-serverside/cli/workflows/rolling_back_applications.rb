require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'

module EY
  module Serverside
    module CLI
      module Workflows
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
