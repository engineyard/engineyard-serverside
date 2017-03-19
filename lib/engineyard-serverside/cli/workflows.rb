require 'engineyard-serverside/cli/workflows/integrating_servers'

module EY
  module Serverside
    module CLI
      module Workflows
        DEFINED = {
          :integrate => IntegratingServers,
        }

        def self.perform(workflow, args = {})
          (DEFINED[workflow] || Base).new(args).perform
        end
      end
    end
  end
end
