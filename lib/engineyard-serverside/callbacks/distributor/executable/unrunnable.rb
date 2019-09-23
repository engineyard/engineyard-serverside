require 'engineyard-serverside/callbacks/distributor/base'

module EY
  module Serverside
    module Callbacks
      module Distributor
        module Executable

          class Unrunnable < Base
            def distribute
              shell.warning "Skipping possible deploy hook #{hook} because it is not executable."
            end
          end

        end
      end
    end
  end
end
