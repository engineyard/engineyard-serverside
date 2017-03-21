require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'
require 'engineyard-serverside/maintenance'

module EY
  module Serverside
    module CLI
      module Workflows

        # ShowingMaintenanceStatus is a Workflow that reports the current
        # enabled/disabled status of the maintenance page for the application
        # specified in the options
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
