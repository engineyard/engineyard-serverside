require 'spec_helper'

require 'pathname'

require 'result'
require 'engineyard-serverside/callbacks/executor'

module EY
  module Serverside
    module Callbacks

      describe Executor do
        let(:config) {Object.new}
        let(:shell) {Object.new}
        let(:ruby_hook) {Object.new}
        let(:executable_hook) {Object.new}
        let(:hooks) {[ruby_hook, executable_hook]}

        before(:each) do
          allow(ruby_hook).to receive(:flavor).and_return(:ruby)
          allow(executable_hook).to receive(:flavor).and_return(:executable)
        end

        describe '.execute' do
          let(:result) {described_class.execute(config, shell, hooks)}

          it 'dispatches each hook to the proper executor' do
            expect(described_class::Ruby).
              to receive(:execute).
              with(config, shell, ruby_hook)

            expect(described_class::Executable).
              to receive(:execute).
              with(config, shell, executable_hook)

            result
          end

        end
      end

    end
  end
end

