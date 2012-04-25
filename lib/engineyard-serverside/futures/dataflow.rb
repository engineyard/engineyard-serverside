module EY
  module Serverside
    $LOAD_PATH.unshift File.expand_path('../../vendor/dataflow', File.dirname(__FILE__))
    require 'dataflow'

    class Future
      extend Dataflow

      def self.call(blocks)
        futures = map(blocks)

        # Dataflow needs to call `barrier` and `need_later` in the same object
        need_laters = futures.map do |future|
          need_later { future.result }
        end
        barrier(*need_laters)

        futures
      end

      def call
        @block.call
      end
    end
  end
end
