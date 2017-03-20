require 'engineyard-serverside/cli/workflows/base'
require 'engineyard-serverside/cli/workflows/helpers'
require 'engineyard-serverside/maintenance'

module EY
  module Serverside
    module CLI
      module Workflows
        class DisablingMaintenance < Base
          include Helpers

          private
          def procedure
            propagate_serverside

            maintenance.manually_disable
          end

          def task_name
            'disable_maintenance'
          end
        end
      end
    end
  end
end
