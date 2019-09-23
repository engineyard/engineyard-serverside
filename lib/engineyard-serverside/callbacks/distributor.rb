require 'engineyard-serverside/callbacks/distributor/ruby'
require 'engineyard-serverside/callbacks/distributor/executable'

module EY
  module Serverside
    module Callbacks

      module Distributor
        FLAVORS = {
          :ruby => Ruby,
          :executable => Executable,
        }

        def self.distribute(runner, hooks)
          hooks.each do |hook|
            FLAVORS[hook.flavor].distribute(runner, hook)
          end
        end
      end

    end
  end
end
