require 'spec_helper'

require 'engineyard-serverside/cli/workflows/disabling_maintenance'

module EY
  module Serverside
    module CLI
      module Workflows
        describe DisablingMaintenance do
          let(:config) {Object.new}
          let(:shell) {Object.new}
          let(:options) {{}}
          let(:maintenance) {Object.new}
          let(:workflow) {described_class.new(options)}

          before(:each) do
            allow(shell).to receive(:fatal)
            allow(shell).to receive(:debug)

            allow(config).to receive(:verbose)
            allow(config).to receive(:app)

            allow(workflow).to receive(:shell).and_return(shell)
            allow(workflow).to receive(:config).and_return(config)
          end

          it 'is a CLI Workflow' do
            expect(workflow).to be_a(EY::Serverside::CLI::Workflows::Base)
          end

          it 'has a task name' do
            expect(workflow.instance_eval {task_name}).
              to eql('disable_maintenance')
          end

          describe '#perform' do
            let(:perform) {workflow.perform}

            before(:each) do
              allow(workflow).to receive(:propagate_serverside)
              allow(workflow).to receive(:maintenance).and_return(maintenance)
              allow(maintenance).to receive(:manually_disable)
            end

            it 'propagates serverside' do
              expect(workflow).to receive(:propagate_serverside)

              perform
            end

            it 'disables maintenance mode for the app' do
              expect(workflow).to receive(:maintenance).and_return(maintenance)
              expect(maintenance).to receive(:manually_disable)
              perform
            end
          end
        end
      end
    end
  end
end
