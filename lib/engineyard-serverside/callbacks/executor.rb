require 'engineyard-serverside/callbacks/executor/ruby'
require 'engineyard-serverside/callbacks/executor/executable'

module EY
  module Serverside
    module Callbacks

      module Executor
        FORMATS = {
          :ruby => Ruby,
          :executable => Executable,
        }

        def self.execute(runner, hooks)
          hooks.each do |hook|
            FORMATS[hook.hook_format].execute(runner, hook)
          end
        end
      end

    end
  end
end
