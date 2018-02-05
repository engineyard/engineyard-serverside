require 'spec_helper'

require 'engineyard-serverside/spawner'

module EY
  module Serverside
    describe Spawner do
      describe '.run' do
        let(:cmd) {'true'}
        let(:shell) {Object.new}
        let(:result) {Object.new}

        let(:run) {described_class.run(cmd, shell)}

        it 'runs the command via a Pool' do
          expect(described_class::Pool).
            to receive(:run).
            and_return(result)

          expect(run).to eql(result)
        end

        context 'when no server is provided' do
          it 'sends a nil server to the Pool' do
            expect(described_class::Pool).
              to receive(:run).
              with(cmd, shell, nil)

            run
          end
        end

        context 'when a server is provided' do
          let(:server) {Object.new}
          let(:run) {described_class.run(cmd, shell, server)}

          it 'sends the server along to the pool' do
            expect(described_class::Pool).
              to receive(:run).
              with(cmd, shell, server)

            run
          end
        end
      end

      describe '.pool' do
        let(:result) {Object.new}
        let(:pool) {described_class.pool}

        it 'is a new Pool' do
          expect(described_class::Pool).to receive(:new).and_return(result)

          expect(pool).to eql(result)
        end
      end

    end
  end
end
