require 'engineyard-serverside/callbacks/collection'

module EY
  module Serverside
    module Callbacks
      def self.load(paths)
        Collection.load(paths)
      end
    end
  end
end
