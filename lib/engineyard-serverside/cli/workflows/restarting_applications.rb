require 'engineyard-serverside/cli/workflows/base'

module EY
  module Serverside
    module CLI
      module Workflows

        # RestartingApplications is a Workflow that restarts the application
        # specified in the options
        class RestartingApplications < Base
          private
          def procedure
            options[:release_path] = Pathname.new(
              "/data/#{options[:app]}/current"
            )

            propagate_serverside

            deployer.restart_with_maintenance_page

          end

          def task_name
            'restart'
          end
        end
      end
    end
  end
end
