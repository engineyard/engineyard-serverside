require 'spec_helper'

require 'result'

require 'engineyard-serverside/callbacks/executor/ruby'

module EY
  module Serverside
    module Callbacks
      module Executor

        describe Ruby do
          let(:config) {Object.new}
          let(:shell) {Object.new}
          let(:hook) {Object.new}

          describe '.execute' do
            let(:result) {described_class.execute(config, shell, hook)}

            it 'forwards the execution to a ruby executor' do
              expect(described_class::Executor).
                to receive(:execute).
                with(config, shell, hook)

              result
            end

          end
        end

      end
    end
  end
end

