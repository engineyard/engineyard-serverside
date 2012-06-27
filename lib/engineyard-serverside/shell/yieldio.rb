module EY
  module Serverside
    class Shell
      class YieldIO
        def initialize(&block)
          @block = block
        end
        def <<(str)
          @block.call str
        end
      end
    end
  end
end
