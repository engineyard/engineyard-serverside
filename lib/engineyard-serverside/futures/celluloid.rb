module EY
  module Serverside
    $LOAD_PATH.unshift File.expand_path('../../vendor/celluloid/lib', File.dirname(__FILE__))
    require 'celluloid'
    class Future
      def self.call(blocks)
        map(blocks).each {|f| f.result }
      end

      def call
        Celluloid::Future.new(&@block).call
      end
    end
  end
end
