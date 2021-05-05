require 'engineyard-serverside/callbacks/collection/base'
require 'engineyard-serverside/callbacks/hooks/app'

module EY
  module Serverside
    module Callbacks
      module Collection

        class DeployHooks < Base
          private
          def load_hooks
            Dir["#{paths.deploy_hooks}/*"].each do |hook_path|
              hooks.push(Hooks::App.new(hook_path))
            end
          end
        end

      end
    end
  end
end
