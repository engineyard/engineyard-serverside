require 'pathname'

module EY
  module Serverside
    module Callbacks

      class BaseHook
        attr_reader :path, :callback_name, :hook_format

        def initialize(file_path)
          @path = Pathname.new(file_path)

          filename = path.basename

          callback = filename.basename('.rb')

          @hook_format = filename == callback ? :executable : :ruby

          @callback_name = callback.to_s.to_sym
        end

        def matches?(callback)
          callback_name == callback
        end

        def to_s
          raise "Unimplemented"
        end
      end

    end
  end
end
