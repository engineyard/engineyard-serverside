require 'pathname'

require 'engineyard-serverside/callbacks/base_hook'

module EY
  module Serverside
    module Callbacks

      class ServiceHook < BaseHook
        attr_reader :service_name

        def initialize(file_path)
          super
          @service_name = path.dirname.basename.to_s
        end
      end

    end
  end
end
