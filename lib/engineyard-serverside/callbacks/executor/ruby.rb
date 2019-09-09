require 'engineyard-serverside/callbacks/executor/ruby/implementation'

module EY
  module Serverside
    module Callbacks
      module Executor

        module Ruby
          def self.execute(runner, hook)
            Implementation.execute(runner, hook)
          end

        end

      end
    end
  end
end
