require 'engineyard-serverside/callbacks/hooks/base'

module EY
  module Serverside
    module Callbacks
      module Hooks

        class Service < Base
          attr_reader :service_name

          def initialize(file_path)
            super
            @service_name = path.dirname.basename.to_s
          end

          def to_s
            "service/#{service_name}/#{callback_name}"
          end

          def short_name
            "#{service_name}/#{callback_name}"
          end
        end

      end
    end
  end
end
