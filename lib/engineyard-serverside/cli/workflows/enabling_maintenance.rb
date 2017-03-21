require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'
require 'engineyard-serverside/maintenance'

module EY
  module Serverside
    module CLI
      module Workflows

        # EnablingMaintenance is a Workflow that puts a maintenance page in
        # place for the application specified in the options
        class EnablingMaintenance < Base
          include Helpers

          private
          def procedure
            propagate_serverside

            maintenance.manually_enable
          end

          def task_name
            'enable_maintenance'
          end
        end
      end
    end
  end
end
