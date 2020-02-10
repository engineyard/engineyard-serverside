require 'spec_helper'

require 'result/failure'

module Result
  describe Failure do
    let(:dummy) {Object.new}
    let(:wrapped) {3}
    let(:result) {described_class.new(wrapped)}

    before(:each) do
      allow(dummy).to receive(:process)
    end

    it 'is a result' do
      expect(result).to be_a(Result::Base)
    end

    it 'is frozen' do
      expect(result).to be_frozen
    end

    describe '#success?' do
      let(:success) {result.success?}

      it 'is false' do
        expect(success).to eql(false)
      end
    end

    describe '#failure?' do
      let(:failure) {result.failure?}

      it 'is true' do
        expect(failure).to eql(true)
      end
    end

    describe '#value' do
      let(:value) {result.value}

      it 'raises an exception' do
        expect {value}.to raise_exception
      end
    end

    describe '#error' do
      let(:error) {result.error}

      it 'is the wrapped error' do
        expect(error).to eql(wrapped)
      end
    end

    describe '#and_then' do
      it 'does not execute the given block' do
        expect(dummy).not_to receive(:process)

        result.and_then {|v| dummy.process(v)}
      end

      it 'is the failure itself' do
        actual = result.and_then {|v| v}

        expect(actual).to eql(result)
      end
    end

    describe '#or_else' do

      it 'yields the wrapped value to the block' do
        expect(dummy).to receive(:process).with(wrapped)

        result.or_else {|v| dummy.process(v)}
      end

      it 'is the result of the block' do
        actual = result.or_else {|v| v + 1}

        expect(actual).to eql(wrapped + 1)
      end
    end

    describe '#on_success' do
      it 'does not call the block' do
        expect(dummy).not_to receive(:process)

        result.on_success {|v| dummy.process(v)}
      end

      it 'is the failure itself' do
        actual = result.on_success {|v| v}

        expect(actual).to eql(result)
      end
    end

    describe '#on_failure' do
      it 'yields the wrapped value to the block' do
        expect(dummy).to receive(:process).with(wrapped)

        result.on_failure {|v| dummy.process(v)}
      end

      it 'is the failure itself' do
        actual = result.on_failure {|v| v}

        expect(actual).to eql(result)
      end
    end

  end
end
