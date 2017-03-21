module EY
  module Serverside
    module CLI
      module Workflows

        # Helpers is a collection of methods that can be mixed into a Workflow
        # to provide easy access to some of the underlying concepts for
        # procedures like deploying, managing maintenance state, etc
        module Helpers
          def deployer
            EY::Serverside::Deploy.new(servers, config, shell)
          end

          def maintenance
            EY::Serverside::Maintenance.new(servers, config, shell)
          end
        end
      end
    end
  end
end
