require 'engineyard-serverside/callbacks/distributor/remote'
require 'engineyard-serverside/callbacks/distributor/viability_filter'

module EY
  module Serverside
    module Callbacks

      module Distributor
        def self.distribute(runner, hooks)
          ViabilityFilter.
            call({:candidates => hooks}).
            and_then {|hook_name|
              Remote.distribute(runner, hook_name)
            }
        end
      end

    end
  end
end
