require 'spec_helper'

require 'engineyard-serverside/callbacks'

module EY
  module Serverside
    describe Callbacks do
      describe '.load' do
        let(:paths) {Object.new}
        let(:collection) {Object.new}
        let(:result) {described_class.load(paths)}

        before(:each) do
          allow(described_class::Collection).
            to receive(:load).
            and_return(collection)
        end

        it 'loads a collection' do
          expect(described_class::Collection).to receive(:load).with(paths)

          result
        end

        it 'is a callbacks collection' do
          expect(result).to eql(collection)
        end
      end
    end
  end
end
