require 'engineyard-serverside/callbacks/executor/executable/runnable'
require 'engineyard-serverside/callbacks/executor/executable/unrunnable'

module EY
  module Serverside
    module Callbacks
      module Executor

        module Executable
          def self.execute(runner, hook)
            (hook.path.executable? ? Runnable : Unrunnable).
              execute(runner, hook)
          end
        end

      end
    end
  end
end
