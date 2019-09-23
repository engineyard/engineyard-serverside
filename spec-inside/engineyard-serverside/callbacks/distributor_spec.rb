require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/distributor'

module EY
  module Serverside
    module Callbacks

      describe Distributor do

        describe '.distribute' do
          let(:runner) {Object.new}
          let(:hook_1) {Object.new}
          let(:hook_2) {Object.new}
          let(:matches) {[hook_2, hook_1]}

          let(:result) {described_class.distribute(runner, matches)}

          before(:each) do
            allow(hook_1).to receive(:flavor).and_return(:ruby)
            allow(hook_2).to receive(:flavor).and_return(:executable)
          end

          it 'dispatches to the proper implementation in the proper order' do
            expect(described_class::Executable).
              to receive(:distribute).
              with(runner, hook_2).
              ordered

            expect(described_class::Ruby).
              to receive(:distribute).
              with(runner, hook_1).
              ordered

            result
          end


        end

      end

    end
  end
end
