require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'
require 'engineyard-serverside/maintenance'

module EY
  module Serverside
    module CLI
      module Workflows
        class ShowingMaintenanceStatus < Base
          include Helpers

          private
          def procedure
            maintenance.status
          end

          def task_name
            'maintenance-status'
          end
        end
      end
    end
  end
end
