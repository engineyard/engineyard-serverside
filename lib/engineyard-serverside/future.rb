module EY
  module Serverside
    class Future
      def self.map(blocks)
        blocks.map { |block| new(&block) }
      end

      def self.success?(futures)
        futures.empty? || futures.all? {|f| f.success?}
      end

      def initialize(&block)
        @block = block
      end

      def result
        @result ||= call
      end

      def success?
        result == true
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
