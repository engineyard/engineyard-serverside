require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/distributor/ruby'

module EY
  module Serverside
    module Callbacks
      module Distributor

        describe Ruby do
          let(:runner) {Object.new}
          let(:hook) {Object.new}
          let(:shell) {Object.new}

          describe '.distribute' do
            let(:result) {described_class.distribute(runner, hook)}

            it 'uses a new distributor to distribute the hook' do
              distributor = Object.new

              expect(described_class).
                to receive(:new).
                with(runner, hook).
                and_return(distributor)

              expect(distributor).to receive(:distribute)

              result
            end
          end

          describe '#distribute' do
            before(:each) do
              allow(runner).to receive(:shell).and_return(shell)
            end

          end
        end

      end
    end
  end
end
