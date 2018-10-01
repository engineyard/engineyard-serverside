require 'result'

module EY
  module Serverside
    module Slug

      class FailureHandler
        def self.handle(data = {})
          new(data[:config], data[:shell], data[:servers]).call(data)
        end

        def initialize(config, shell, servers)
          @config = config
          @shell = shell
          @servers = servers
        end

        def call(data = {})
          Result::Failure.new(data)
        end
      end
    end
  end
end
