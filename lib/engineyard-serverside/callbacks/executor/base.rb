module EY
  module Serverside
    module Callbacks
      module Executor

        class Base
          attr_reader :runner, :hook

          def self.execute(runner, hook)
            new(runner, hook).execute
          end

          def initialize(runner, hook)
            @runner = runner
            @hook = hook
          end

          def execute
            raise 'Unimplemented Hook Executor!'
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
