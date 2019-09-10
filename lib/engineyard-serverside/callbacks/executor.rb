require 'engineyard-serverside/callbacks/executor/ruby'
require 'engineyard-serverside/callbacks/executor/executable'

module EY
  module Serverside
    module Callbacks

      module Executor
        FLAVORS = {
          :ruby => Ruby,
          :executable => Executable,
        }

        def self.execute(runner, hooks)
          hooks.each do |hook|
            FLAVORS[hook.flavor].execute(runner, hook)
          end
        end
      end

    end
  end
end
