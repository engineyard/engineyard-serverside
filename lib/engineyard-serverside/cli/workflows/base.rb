module EY
  module Serverside
    module CLI
      module Workflows
        class Undefined < StandardError
        end

        class Base
          attr_reader :args

          def initialize(args = {})
            @args = args
          end

          def perform
            raise Undefined.new("The #{self.class} workflow is undefined.")
          end

          def self.perform(args = {})
            new(args).perform
          end
        end
      end
    end
  end
end
