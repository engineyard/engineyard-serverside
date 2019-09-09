require 'engineyard-serverside/callbacks/base_hook'

module EY
  module Serverside
    module Callbacks

      class AppHook < BaseHook
        def to_s
          "deploy/#{callback_name}"
        end
      end

    end
  end
end
