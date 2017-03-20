require 'engineyard-serverside/cli/workflows/base'

module EY
  module Serverside
    module CLI
      module Workflows
        class RestartingApplications < Base
          private
          def procedure
            restart_options[:release_path] = Pathname.new(
              "/data/#{options[:app]}/current"
            )

            propagate_serverside

            EY::Serverside::Deploy.
              new(servers, config, shell).
              restart_with_maintenance_page

          end

          def restart_options
            @restart_options ||= options.dup
          end

          def task_name
            'restart'
          end
        end
      end
    end
  end
end
