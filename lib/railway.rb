require 'result'

module Railway
  include Result::DSL

  module DSL
    def step(name, options = {})
      with = options.delete(:with)
      steps.push(:name => name, :with => with)
    end

    def steps
      @steps ||= []
    end
  end

  def self.included(base)
    base.send :extend, DSL
  end

  def call(input = {})
    steps = self.class.steps

    return Failure('No steps') if steps.empty?

    steps.
      inject(Success(input)) {|result, step|
        result.and_then {|data|
          dispatch_step(step, data)
        }
      }
  end

  private
  def dispatch_step(step, data)
    begin
      result = (step[:with] || self).send(step[:name], data)
      result.is_a?(Result::Base) ? result : Success(result)
    rescue => error
      Failure(error)
    end
  end
end
