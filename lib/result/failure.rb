require 'result/base'

module Result

  class Failure < Base
    def initialize(to_wrap)
      super
      freeze
    end

    def error
      @wrapped
    end

    def failure?
      true
    end

    def or_else
      yield error
    end

    def on_failure
      yield error
      super
    end
  end

end
