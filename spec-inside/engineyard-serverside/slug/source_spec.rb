require 'spec_helper'

require 'engineyard-serverside/slug/source'

module EY
  module Serverside
    module Slug
      describe Source do
        let(:servers) {[]}
        let(:config) {Object.new}
        let(:shell) {Object.new}

        describe '.update' do
          let(:input) {
            {:servers => servers, :config => config, :shell => shell}
          }

          let(:update) {described_class.update(input)}

          it 'updates with a new updater' do
            result = Result.Success(nil)
            updater = Object.new

            expect(updater).
              to receive(:update).
              and_return(result)

            expect(described_class::Updater).
              to receive(:new).
              with(input).
              and_return(updater)

            expect(update).to eql(result)
          end
        end

      end
    end
  end
end
