require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/collection'

module EY
  module Serverside
    module Callbacks
      module Collection

        describe ServiceHooks do
          let(:paths) {Object.new}

          describe '.load' do
            let(:combined) {Object.new}
            let(:result) {described_class.load(paths)}

            it 'is a combined service hooks collection' do
              expect(described_class::Combined).
                to receive(:load).with(paths).and_return(combined)

              expect(result).to eql(combined)
            end
          end
        end

      end
    end
  end
end
