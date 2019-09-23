require 'engineyard-serverside/callbacks/distributor'

module EY
  module Serverside
    module Callbacks

      module Collection
        class Base
          def self.load(paths)
            new(paths)
          end

          def initialize(paths)
            @paths = paths
            load_hooks
          end

          def all
            hooks
          end

          def matching(callback)
            favor(
              :ruby,
              all.select {|hook| hook.matches?(callback.to_sym)}
            )
          end

          def distribute(runner, callback)
            Distributor.distribute(runner, matching(callback))
          end

          private
          def favor(flavor, hooks)
            (
              hooks.select {|hook| hook.flavor == flavor} + 
              hooks.reject {|hook| hook.flavor == flavor}
            ).first(1)
          end

          def load_hooks
            raise "Unimplemented"
          end

          def paths
            @paths
          end

          def hooks
            @hooks ||= []
          end
        end

      end
    end
  end
end
