module EY
  module Serverside
    class Future
      def self.success?(futures)
        futures.empty? || futures.all? {|f| f.success?}
      end

      def initialize(server, *args, &block)
        @server = server
        @args = args
        @block = block
      end

      def success?
        @value == true
      end

      def error?
        !success?
      end
    end

    if defined?(Fiber)
      require 'engineyard-serverside/futures/celluloid'
    else
      require 'engineyard-serverside/futures/dataflow'
    end
  end
end
