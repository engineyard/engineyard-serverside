require 'engineyard-serverside/callbacks/hooks/base'

module EY
  module Serverside
    module Callbacks
      module Hooks

        class App < Base
          def to_s
            "deploy/#{callback_name}"
          end
        end

      end
    end
  end
end
