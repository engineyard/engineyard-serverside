require 'engineyard-serverside/callbacks/distributor/remote'
require 'engineyard-serverside/callbacks/distributor/viability_filter'

module EY
  module Serverside
    module Callbacks

      module Distributor
        def self.distribute(runner, callback_name)
          Remote.distribute(runner, callback_name)
        end
      end

    end
  end
end
