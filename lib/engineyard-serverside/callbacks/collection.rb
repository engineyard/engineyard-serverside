require 'engineyard-serverside/callbacks/app_hook'
require 'engineyard-serverside/callbacks/executor'

module EY
  module Serverside
    module Callbacks

      class Collection
        attr_reader :app_hooks

        def self.load(paths)
          new(paths)
        end

        def initialize(paths)
          @paths = paths
          load_app_hooks
        end

        def all
          app_hooks
        end

        def matching(callback)
          all.select {|hook| hook.matches?(callback.to_sym)}
        end

        def execute(runner, callback)
          Executor.execute(runner, matching(callback))
        end

        private
        def load_app_hooks
          @app_hooks ||= []

          Dir["#{paths.deploy_hooks}/*"].each do |hook_path|
            @app_hooks.push(AppHook.new(hook_path))
          end
        end

        def paths
          @paths
        end
      end

    end
  end
end
