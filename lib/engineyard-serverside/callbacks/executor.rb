require 'engineyard-serverside/callbacks/executor/executable'
require 'engineyard-serverside/callbacks/executor/ruby'

module EY
  module Serverside
    module Callbacks

      module Executor
        FLAVORS = {
          :ruby => Ruby,
          :executable => Executable
        }

        def self.execute(config, shell, hooks)
          hooks.each do |hook|
            FLAVORS[hook.flavor].execute(config, shell, hook)
          end
        end
      end

    end
  end
end
