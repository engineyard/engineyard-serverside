require 'engineyard-serverside/callbacks/executor/base'

module EY
  module Serverside
    module Callbacks
      module Executor
        module Executable

          class Unrunnable < Base
            def execute
              shell.warning "Skipping possible deploy hook #{hook} because it is not executable."
            end
          end

        end
      end
    end
  end
end
