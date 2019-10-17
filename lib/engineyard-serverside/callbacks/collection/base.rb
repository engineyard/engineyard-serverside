require 'engineyard-serverside/callbacks/distributor'
require 'engineyard-serverside/callbacks/executor'

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
            Distributor.distribute(
              runner,
              minimize_ruby(
                matching(callback)
              )
            )
          end

          def execute(config, shell, callback)
            Executor.execute(
              config,
              shell,
              matching(callback)
            )
          end

          private
          def favor(flavor, hooks)
            (
              hooks.select {|hook| hook.flavor == flavor} + 
              hooks.reject {|hook| hook.flavor == flavor}
            ).first(1)
          end

          def minimize_ruby(hooks)
            first_ruby = hooks.select {|hook| hook.flavor == :ruby}.first

            return hooks unless first_ruby

            ([first_ruby] + hooks.select {|hook| hook.flavor != :ruby}).flatten
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
