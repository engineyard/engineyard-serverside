module EY
  module Serverside
    $LOAD_PATH.unshift File.expand_path('../../vendor/celluloid/lib', File.dirname(__FILE__))
    require 'celluloid'
    class Future
      def self.call(servers, *args, &block)
        futures = servers.map do |server|
          new(server, *args, &block)
        end

        futures.each {|f| f.call}
        futures
      end

      def future
        Celluloid::Future.new(@server, *@args, &@block)
      end

      def call
        # Celluloid needs to call the block explicitely
        @value ||= future.call
      end
    end
  end
end
