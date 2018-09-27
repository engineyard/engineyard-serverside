require 'result/success'
require 'result/failure'

module Result

  module DSL
    def Success(value)
      Success.new(value)
    end

    def Failure(error)
      Failure.new(error)
    end
  end

end
