require 'railway'

module EY
  module Serverside
    module Callbacks
      module Executor

        class Base
          include Railway

          attr_reader :config, :shell, :hook

          def self.execute(config, shell, hook)
            new(config, shell, hook).execute
          end

          def initialize(config, shell, hook)
            @config = config
            @shell = shell
            @hook = hook
          end

          def execute
            call.or_else {|payload| handle_failure(payload)}
          end

          def handle_failure(payload = {})
            raise "Unimplemented Hook Executor!"
          end

          def paths
            config.paths
          end

          def hook_path
            hook.path
          end

        end

      end
    end
  end
end
