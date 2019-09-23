require 'engineyard-serverside/callbacks/collection/base'
require 'engineyard-serverside/callbacks/collection/deploy_hooks'
require 'engineyard-serverside/callbacks/collection/service_hooks'

module EY
  module Serverside
    module Callbacks
      module Collection

        class Combined < Base
          def all
            collections.
              map {|collection| collection.all}.
              flatten
          end

          def matching(callback)
            collections.
              map {|collection| collection.matching(callback)}.
              flatten
          end

          private
          def load_hooks
            @service_hooks = ServiceHooks.load(paths)
            @app_hooks = DeployHooks.load(paths)
          end

          def app_hooks
            @app_hooks
          end

          def service_hooks
            @service_hooks
          end

          def collections
            [service_hooks, app_hooks]
          end
        end

      end
    end
  end
end
