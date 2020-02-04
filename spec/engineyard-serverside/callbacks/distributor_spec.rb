require 'spec_helper'

require 'pathname'

require 'result'
require 'engineyard-serverside/callbacks/distributor'

module EY
  module Serverside
    module Callbacks

      describe Distributor do

        describe '.distribute' do
          let(:runner) {Object.new}
          let(:shell) {Object.new}
          let(:hook_name) {:some_hook}
          let(:failure) {Result::Failure.new({})}
          let(:success) {Result::Success.new(hook_name)}

          let(:result) {described_class.distribute(runner, hook_name)}

          before(:each) do
            allow(described_class::Remote).to receive(:distribute)

            allow(runner).to receive(:shell).and_return(shell)
          end

          it 'distributes the hook remotely' do
            expect(described_class::Remote).
              to receive(:distribute).
              with(runner, hook_name)

            result
          end

        end

      end

    end
  end
end
