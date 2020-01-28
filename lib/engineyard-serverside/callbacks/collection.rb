require 'engineyard-serverside/callbacks/collection/combined'

module EY
  module Serverside
    module Callbacks

      module Collection
        attr_reader :app_hooks

        def self.load(paths)
          Combined.load(paths)
        end
      end

    end
  end
end
