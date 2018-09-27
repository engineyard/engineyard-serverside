require 'result/base'

module Result

  class Success < Base
    def value
      @wrapped
    end

    def success?
      true
    end

    def and_then
      yield value
    end

    def on_success
      yield value
      super
    end
  end

end
