module EY
  module Serverside
    $LOAD_PATH.unshift File.expand_path('../../vendor/dataflow', File.dirname(__FILE__))
    require 'dataflow'

    class Future
      extend Dataflow

      def self.call(servers, *args, &block)
        futures = []
        # Dataflow needs to call `barrier` and `need_later` in the same object
        barrier(*servers.map do |server|
          future = new(server, *args, &block)
          futures << future

          need_later { future.call }
        end)

        futures
      end

      def future
        @block.call(@server, *@args)
      end

      def call
        @value ||= future
      end
    end
  end
end
