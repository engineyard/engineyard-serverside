require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/collection/combined'

module EY
  module Serverside
    module Callbacks
      module Collection

        describe Combined do
          let(:paths) {Object.new}
          let(:deploy_hook_1) {Object.new}
          let(:deploy_hook_2) {Object.new}
          let(:service_hook_1) {Object.new}
          let(:service_hook_2) {Object.new}
          let(:deploy_hooks) {Object.new}
          let(:service_hooks) {Object.new}

          let(:collection) {described_class.load(paths)}

          before(:each) do
            # Stub out the DeployHooks collection upon which we depend
            allow(DeployHooks).
              to receive(:load).
              with(paths).
              and_return(deploy_hooks)

            allow(deploy_hooks).
              to receive(:all).
              and_return([deploy_hook_1, deploy_hook_2])

            allow(deploy_hooks).
              to receive(:matching).
              and_return([deploy_hook_1])

            # Stub out the ServiceHooks collection upon which we depend
            allow(ServiceHooks).
              to receive(:load).
              with(paths).
              and_return(service_hooks)

            allow(service_hooks).
              to receive(:all).
              and_return([service_hook_1, service_hook_2])

            allow(service_hooks).
              to receive(:matching).
              and_return([service_hook_2])

            # Make all of our "hooks" of the executable flavor by default
            [
              deploy_hook_1, deploy_hook_2, service_hook_1, service_hook_2
            ].each do |hook|
              allow(hook).to receive(:flavor).and_return(:executable)
            end

          end

          describe '.load' do
            let(:deploy_hooks) {Object.new}
            let(:service_hooks) {Object.new}
            let(:result) {described_class.load(paths)}


            it 'loads deploy hooks' do
              expect(DeployHooks).to receive(:load).with(paths)

              result
            end

            it 'loads service hooks' do
              expect(ServiceHooks).to receive(:load).with(paths)

              result
            end

            it 'is a callbacks collection' do
              expect(result).to be_a(Collection::Base)
            end
          end

          describe '#all' do
            let(:result) {collection.all}

            it 'is an Array' do
              expect(result).to be_a(Array)
            end

            it 'contains the deploy hooks' do
              [deploy_hook_1, deploy_hook_2].each do |hook|
                expect(result).to include(hook)
              end
            end

            it 'contains the service hooks' do
              [service_hook_1, service_hook_2].each do |hook|
                expect(result).to include(hook)
              end
            end

            it 'gives more priority to service hooks' do
              expect(result).to eql(
                [service_hook_1, service_hook_2, deploy_hook_1, deploy_hook_2]
              )
            end
          end

          describe '#matching' do
            let(:name) {:hook_2}
            let(:result) {collection.matching(name)}

            it 'is an Array' do
              expect(result).to be_a(Array)
            end

            it 'contains hooks with the desired name' do
              [service_hook_2, deploy_hook_1].each do |hook|
                expect(result).to include(hook)
              end
            end

            it 'omits hooks without the desired name' do
              [service_hook_1, deploy_hook_2].each do |hook|
                expect(result).not_to include(hook)
              end
            end
          end

          describe '#execute' do
            let(:config) {Object.new}
            let(:shell) {Object.new}
            let(:callback) {Object.new}
            let(:matches) {[]}

            let(:result) {collection.execute(config, shell, callback)}

            before(:each) do
              allow(Executor).to receive(:execute)
              allow(shell).to receive(:info)
              allow(collection).
                to receive(:matching).
                with(callback).
                and_return(matches)
            end

            context 'when there are matching hooks' do
              let(:matches) {[Object.new]}

              it 'executes those matching hooks' do
                expect(Executor).to receive(:execute).with(config, shell, matches)

                result
              end
            end

            context 'when there are not matching hooks' do
              let(:matches) {[]}

              it 'logs a message about the lack of matching hooks' do
                expect(shell).
                  to receive(:info).
                  with("No hooks detected for #{callback}. Skipping.")

                result
              end

              it 'does not execute any hooks' do
                expect(Executor).not_to receive(:execute)

                result
              end
            end
          end

          describe '#distribute' do
            let(:runner) {Object.new}
            let(:name) {:hook_2}
            let(:distributor) {Callbacks::Distributor}
            let(:distribution_result) {Object.new}
            let(:matched) {[service_hook_2, deploy_hook_1]}
            let(:result) {collection.distribute(runner, name)}

            before(:each) do
              allow(distributor).to receive(:distribute)
            end

            it 'distributes matching hooks via an distributor' do
              expect(distributor).
                to receive(:distribute).
                with(runner, matched).
                and_return(distribution_result)

              expect(result).to eql(distribution_result)
            end

            it 'skips non-matching hooks' do
              expect(distributor).not_to receive(:distribute).with(runner, :hook_1)

              result
            end

            context 'when there are multiple matching ruby hooks' do
              before(:each) do
                allow(service_hook_2).to receive(:flavor).and_return(:ruby)
                allow(deploy_hook_1).to receive(:flavor).and_return(:ruby)
              end

              it 'distributes the first ruby hook' do
                expect(distributor).
                  to receive(:distribute).
                  with(runner, [service_hook_2])

                result
              end

              it 'does not distribute any other ruby hook' do
                expect(distributor).
                  not_to receive(:distribute).
                  with(runner, [service_hook_2, deploy_hook_1])

                result
              end
            end
          end
        end

      end
    end
  end
end
