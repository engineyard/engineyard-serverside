module EY
  module Serverside
    module CLI
      module Workflows
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
