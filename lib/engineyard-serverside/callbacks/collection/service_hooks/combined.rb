require 'engineyard-serverside/callbacks/collection/base'
require 'engineyard-serverside/callbacks/collection/service_hooks/collection'

module EY
  module Serverside
    module Callbacks
      module Collection
        module ServiceHooks

          class Combined < EY::Serverside::Callbacks::Collection::Base

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
              Dir["#{paths.shared_hooks}/*"].each do |service_path|
                collections.push(ServiceHooks::Collection.load(service_path))
              end
            end

            def collections
              @collections ||= []
            end
          end

        end
      end
    end
  end
end
