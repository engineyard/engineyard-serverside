require 'spec_helper'


require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    class Shell

      describe Helpers do
        let(:shell) {Object.new}
        let(:verbosity) {false}

        let(:extended) {Object.new.extend(described_class)}

        before(:each) do
          allow(extended).to receive(:shell).and_return shell

          allow(shell).to receive(:verbose?).and_return(verbosity)
          allow(shell).to receive(:warning)
          allow(shell).to receive(:info)
          allow(shell).to receive(:debug)
          allow(shell).to receive(:logged_system)
        end

        describe '#verbose?' do
          let(:result) {extended.verbose?}

          context 'when the shell is configured for verbosity' do
            let(:verbosity) {true}

            it 'is true' do
              expect(result).to eql(true)
            end
          end

          context 'when the shell is not configured for vverbosity' do
            let(:verbosity) {false}

            it 'is false' do
              expect(result).to eql(false)
            end
          end
        end

        describe '#warning' do
          let(:foo) {'foo'}
          let(:bar) {'bar'}
          let(:result) {extended.warning(foo, bar)}

          it 'forwards the request to the shell' do
            expect(shell).to receive(:warning).with(foo, bar)

            result
          end
        end

        describe '#info' do
          let(:foo) {'foo'}
          let(:bar) {'bar'}
          let(:result) {extended.info(foo, bar)}

          it 'forwards the request to the shell' do
            expect(shell).to receive(:info).with(foo, bar)

            result
          end

        end

        describe '#debug' do
          let(:foo) {'foo'}
          let(:bar) {'bar'}
          let(:result) {extended.debug(foo, bar)}

          it 'forwards the request to the shell' do
            expect(shell).to receive(:debug).with(foo, bar)

            result
          end
        end

        describe '#logged_system' do
          let(:foo) {'foo'}
          let(:bar) {'bar'}
          let(:result) {extended.logged_system(foo, bar)}

          it 'forwards the request to the shell' do
            expect(shell).to receive(:logged_system).with(foo, bar)

            result
          end
        end
      end

    end
  end
end
