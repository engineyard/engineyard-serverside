require 'engineyard-serverside/callbacks/collection/service_hooks/combined'

module EY
  module Serverside
    module Callbacks
      module Collection

        module ServiceHooks
          def self.load(paths)
            Combined.load(paths)
          end
        end

      end
    end
  end
end
