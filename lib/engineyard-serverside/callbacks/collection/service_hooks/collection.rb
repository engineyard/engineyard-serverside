require 'engineyard-serverside/callbacks/collection/base'
require 'engineyard-serverside/callbacks/hooks/service'

module EY
  module Serverside
    module Callbacks
      module Collection
        module ServiceHooks

          class Collection < EY::Serverside::Callbacks::Collection::Base

            private
            def load_hooks
              Dir["#{paths}/*"].each do |hook_path|
                hooks.push(Hooks::Service.new(hook_path))
              end
            end
          end

        end
      end
    end
  end
end
