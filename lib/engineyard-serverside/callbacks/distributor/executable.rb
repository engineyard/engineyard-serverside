require 'engineyard-serverside/callbacks/distributor/executable/runnable'
require 'engineyard-serverside/callbacks/distributor/executable/unrunnable'

module EY
  module Serverside
    module Callbacks
      module Distributor

        module Executable
          def self.distribute(runner, hook)
            (hook.path.executable? ? Runnable : Unrunnable).
              distribute(runner, hook)
          end
        end

      end
    end
  end
end
