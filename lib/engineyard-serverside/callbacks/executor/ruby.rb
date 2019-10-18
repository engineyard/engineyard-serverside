require 'rbconfig'
require 'railway'

require 'engineyard-serverside/callbacks/executor/ruby/executor'

module EY
  module Serverside
    module Callbacks
      module Executor

        module Ruby
          def self.execute(config, shell, hook)
            Executor.execute(config, shell,hook)
          end
        end

      end
    end
  end
end
