require 'spec_helper'

require 'engineyard-serverside/cli/workflows'

module EY
  module Serverside
    module CLI
      describe Workflows do
        describe '.normalized' do
          let(:expected) {:shabutie}
          let(:workflow_name) {expected}

          let(:normalized) {described_class.normalized(workflow_name)}

          context 'when given a nil workflow name' do
            let(:workflow_name) {nil}

            it 'is nil' do
              expect(normalized).to be_nil
            end
          end

          context 'when given a workflow name string' do
            let(:workflow_name) {'shabutie'}

            it 'is the symbolized version of the string' do
              expect(normalized).to eql(:shabutie)
            end
          end

          context 'when given a workflow name symbol' do
            it 'is returned unchanged' do
              expect(normalized).to eql(expected)
            end
          end
        end

        describe '.resolve' do
          let(:workflow_name) {nil}
          let(:resolve) {described_class.resolve(workflow_name)}

          context 'when given a nil workflow name' do
            it 'is the base workflow' do
              expect(resolve).to eql(described_class::Base)
            end
          end

          context 'when given an unknown workflow name' do
            let(:workflow_name) {:john_q_public}

            it 'is the base workflow' do
              expect(resolve).to eql(described_class::Base)
            end
          end

          context 'when given a known workflow name' do
            it 'is the requested workflow' do
              described_class::DEFINED.each_pair do |workflow_name, workflow|
                expect(described_class.resolve(workflow_name)).to eql(workflow)
              end
            end
          end
        end

        describe '.perform' do
          let(:resolved) {Object.new}
          let(:workflow_name) {:gandalf}
          let(:options) {{}}

          let(:perform) {described_class.perform(workflow_name, options)}

          it 'performs the requested workflow' do
            expect(described_class).
              to receive(:resolve).
              with(workflow_name).
              and_return(resolved)

            expect(resolved).to receive(:perform).with(options)

            perform
          end
        end

      end
    end
  end
end
