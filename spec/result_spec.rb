require 'spec_helper'

require 'result'

describe Result do
  let(:value) {3}

  describe '.Success' do
    let(:result) {described_class.Success(value)}

    it 'is a success' do
      expect(result).to be_a(described_class::Success)
    end
  end

  describe '.Failure' do
    let(:result) {described_class.Failure(value)}

    it 'is a failure' do
      expect(result).to be_a(described_class::Failure)
    end
  end
end
