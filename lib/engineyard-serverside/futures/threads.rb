module EY
  module Serverside
    class Future
      def self.call(blocks)
        threads = map(blocks).map do |future|
          Thread.new do
            future.result
            future
          end
        end
        threads.map(&:value)
      end

      def call
        @block.call
      end
    end
  end
end
