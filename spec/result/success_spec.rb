require 'spec_helper'

require 'result/success'

module Result
  describe Success do
    let(:dummy) {Object.new}
    let(:wrapped) {3}
    let(:result) {described_class.new(wrapped)}

    before(:each) do
      allow(dummy).to receive(:process)
    end

    it 'is a result' do
      expect(result).to be_a(Result::Base)
    end

    describe '#success?' do
      let(:success) {result.success?}

      it 'is true' do
        expect(success).to eql(true)
      end
    end

    describe '#failure?' do
      let(:failure) {result.failure?}

      it 'is false' do
        expect(failure).to eql(false)
      end
    end

    describe '#value' do
      let(:value) {result.value}

      it 'is the wrapped value' do
        expect(value).to eql(wrapped)
      end
    end

    describe '#error' do
      let(:error) {result.error}

      it 'raises an exception' do
        expect {error}.to raise_exception
      end
    end

    describe '#and_then' do
      it 'yields the wrapped value to the block' do
        expect(dummy).to receive(:process).with(wrapped)

        result.and_then {|v| dummy.process(v)}
      end

      it 'is the result of yielding the wrapped value to the block' do
        actual = result.and_then {|v| v + 1}

        expect(actual).to eql(wrapped + 1)
      end
    end

    describe '#or_else' do
      it 'does not call the block' do
        expect(dummy).not_to receive(:process)

        result.or_else {|v| dummy.process(v)}
      end

      it 'is the success itself' do
        actual = result.or_else {|v| v}

        expect(actual).to eql(result)
      end
    end

    describe '#on_success' do
      it 'yields the wrapped value to the block' do
        expect(dummy).to receive(:process).with(wrapped)

        result.on_success {|v| dummy.process(v)}
      end

      it 'is the success itself' do
        actual = result.on_success {|v| v}

        expect(actual).to eql(result)
      end
    end

    describe '#on_failure' do
      it 'does not call the block' do
        expect(dummy).not_to receive(:process)

        result.on_failure {|v| dummy.process(v)}
      end

      it 'is the success itself' do
        actual = result.on_failure {|v| v}

        expect(actual).to eql(result)
      end
    end


  end
end
