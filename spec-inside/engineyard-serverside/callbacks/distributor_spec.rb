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
          let(:hook_1) {Object.new}
          let(:hook_2) {Object.new}
          let(:matches) {[hook_2, hook_1]}
          let(:filter) {Object.new}
          let(:hook_name) {:some_hook}
          let(:filter_args) {{:candidates => matches}}
          let(:failure) {Result::Failure.new({})}
          let(:success) {Result::Success.new(hook_name)}

          let(:result) {described_class.distribute(runner, matches)}

          before(:each) do
            allow(hook_1).to receive(:flavor).and_return(:ruby)
            allow(hook_2).to receive(:flavor).and_return(:executable)
            allow(described_class::ViabilityFilter).
              to receive(:new).
              and_return(filter)

            allow(described_class::Remote).to receive(:distribute)

            allow(filter).to receive(:call)
          end

          it 'filters the hooks for viability' do
            expect(filter).
              to receive(:call).
              with(filter_args).
              and_return(failure)

            result
          end

          context 'when there are viable hooks given' do
            before(:each) do
              allow(filter).
                to receive(:call).
                with({:candidates => matches}).
                and_return(Result::Success.new(hook_name))
            end

            it 'distributes the hook remotely' do
              expect(described_class::Remote).
                to receive(:distribute).
                with(runner, hook_name)

              result
            end
          end

          context 'when no viable hooks are given' do
            before(:each) do
              allow(filter).
                to receive(:call).
                with({:candidates => matches}).
                and_return(Result::Failure.new({}))
            end

            it 'distributes no hooks' do
              expect(described_class::Remote).
                not_to receive(:distribute)

              result
            end
          end

        end

      end

    end
  end
end
