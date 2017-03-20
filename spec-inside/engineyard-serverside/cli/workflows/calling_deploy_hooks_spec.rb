require 'spec_helper'

require 'engineyard-serverside/cli/workflows/calling_deploy_hooks'

module EY
  module Serverside
    module CLI
      module Workflows
        describe CallingDeployHooks do
          let(:config) {Object.new}
          let(:shell) {Object.new}
          let(:hook_name) {'joe'}
          let(:options) {{:hook_name => hook_name}}
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
              to eql("hook-#{hook_name}")
          end

          describe '#perform' do
            let(:deploy_hook) {Object.new}

            let(:perform) {workflow.perform}

            before(:each) do
              allow_any_instance_of(EY::Serverside::DeployHook).
                to receive(:call)
            end

            it 'does not propagates serverside' do
              expect(workflow).not_to receive(:propagate_serverside)

              perform
            end

            it 'calls the requested deploy hook' do
              expect(EY::Serverside::DeployHook).
                to receive(:new).
                with(config, shell, hook_name).
                and_return(deploy_hook)

              expect(deploy_hook).to receive(:call)

              perform
            end
          end
        end
      end
    end
  end
end
