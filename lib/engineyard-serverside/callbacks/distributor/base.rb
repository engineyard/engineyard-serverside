module EY
  module Serverside
    module Callbacks
      module Distributor

        class Base
          attr_reader :runner, :hook

          def self.distribute(runner, hook)
            new(runner, hook).distribute
          end

          def initialize(runner, hook)
            @runner = runner
            @hook = hook
          end

          def distribute
            raise 'Unimplemented Hook Distributor!'
          end

          def config
            runner.config
          end

          def shell
            runner.shell
          end

          def paths
            runner.paths
          end
        end

      end
    end
  end
end
