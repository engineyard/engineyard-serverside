require 'spec_helper'

require 'railway'

class ComplicatedProcess
  include Railway

  step :step_1
  step :step_2
  step :step_3
end

class EmptyProcess
  include Railway
end

describe Railway do
  let(:steps) {[:step_1, :step_2, :step_3]}
  let(:dummy) {ComplicatedProcess.new}

  before(:each) do
    steps.each do |step|
      allow(dummy).to receive(step).and_return(Result.Success(nil))
    end
  end

  describe '#call' do
    let(:input) {nil}
    let(:result) {dummy.call(input)}

    it 'has a default argument' do
      expect {dummy.call}.not_to raise_error
    end

    it 'passes the output of one step to the next step as input' do
      allow(dummy).to receive(:step_1).and_return('step 1')
      expect(dummy).to receive(:step_2).with('step 1').and_return('step 2')
      expect(dummy).to receive(:step_3).with('step 2').and_return('step 3')

      result
    end

    context 'when all steps are successful' do
      it 'executes all steps' do
        steps.each do |step|
          expect(dummy).to receive(step).and_return(Result.Success(nil))
        end

        result
      end

      it 'returns a success' do
        expect(result).to be_a(Result::Success)
      end
    end

    context 'when a step fails' do
      let(:failing_step) {:step_1}
      let(:failure) {Result.Failure(nil)}

      before(:each) do
        allow(dummy).to receive(:step_1).and_return(failure)
      end

      it 'executes all steps up to that step' do
        expect(dummy).to receive(:step_1).and_return(failure)

        result
      end

      it 'does not execute steps after the failing step' do
        (steps - [failing_step]).each do |step|
          expect(dummy).not_to receive(step)
        end

        result
      end

      it 'returns the failure' do
        expect(result).to eql(failure)
      end
    end

    context 'when a step returns something other than a result' do
      before(:each) do
        steps.each do |step|
          allow(dummy).to receive(step).and_return(step.to_s)
        end
      end

      it 'treats the return value as a Success' do
        expect(dummy).to receive(:step_2).with('step_1').and_return('step_2')
        expect(dummy).to receive(:step_3).with('step_2').and_return('step_3')

        expect(result).to be_a(Result::Success)
        expect(result.value).to eql('step_3')
      end
    end

    context 'when a step raises an error' do
      let(:failing_step) {:step_1}
      let(:error) {RuntimeError.new('a big nasty error')}

      before(:each) do
        allow(dummy).to receive(:step_1).and_raise(error)
      end

      it 'treats the step as a failure' do
        (steps - [failing_step]).each do |step|
          expect(dummy).not_to receive(step)
        end

        expect(result).to be_a(Result::Failure)
        expect(result.error).to eql(error)
      end
    end

    context 'when there are no steps' do
      let(:dummy) {EmptyProcess.new}

      it 'is a failure' do
        expect(result).to be_a(Result::Failure)
      end

      it 'has an error regarding the lack of steps' do
        expect(result.error).to eql('No steps')
      end
    end
  end
end
