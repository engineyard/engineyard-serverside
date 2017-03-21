require 'spec_helper'

require 'engineyard-serverside/cli/workflows/base'

module EY
  module Serverside
    module CLI
      module Workflows
        describe Base do
          let(:shell) {Object.new}
          let(:config) {Object.new}
          let(:options) {{}}
          let(:workflow) {described_class.new(options)}

          before(:each) do
            # Both the Shell and Deploy::Configuration classes are used in
            # the Workflow private API. However, since we're not actually
            # testing their behavior (nor that of an actual workflow) here,
            # we'll need to make sure that we can use them in a predictable
            # way.
            allow(EY::Serverside::Shell).
              to receive(:new).
              and_return(shell)

            allow(EY::Serverside::Deploy::Configuration).
              to receive(:new).
              and_return(config)

            allow(shell).to receive(:fatal)
            allow(shell).to receive(:debug)

            allow(config).to receive(:verbose)
            allow(config).to receive(:app)
          end

          describe '#options' do
            it 'is the options passed in during creation' do
              expect(workflow.options).to eql(options)
            end
          end

          describe '#perform' do
            let(:perform) {workflow.perform}

            before(:each) do
              # Technically, this is against the rules, because I'm stubbing
              # methods on the object under test. They're private methods,
              # though, so I reckon that's probably acceptable.
              allow(workflow).to receive(:procedure)
              allow(workflow).to receive(:task_name)
            end

            it 'announces the serverside init' do
              expect(shell).
                to receive(:debug).
                with("Initializing #{EY::Serverside::About.name_with_version}.")

              perform
            end

            it 'calls its internal procedure' do
              expect(workflow).to receive(:procedure)

              perform
            end

            context 'when the procedure raises a remote failure' do
              let(:error_message) {'onoes'}

              before(:each) do
                allow(workflow).
                  to receive(:procedure).
                  and_raise(EY::Serverside::RemoteFailure.new(error_message))

              end

              it 'logs a fatal error and re-raises' do
                expect(shell).to receive(:fatal).with(error_message)

                expect {perform}.to raise_error(EY::Serverside::RemoteFailure)
              end
            end

            context 'when the procedure raises an unhandled exception' do
              let(:error_message) {'the system is down'}
              let(:exception) {Exception.new(error_message)}

              before(:each) do
                allow(workflow).
                  to receive(:procedure).
                  and_raise(exception)

                # Apparently, instantiating an exception in specs gets a bit
                # wonky.
                allow(exception).to receive(:backtrace).and_return(['darn'])
              end

              it 'logs a fatal error and re-raises' do
                expect(shell).
                  to receive(:fatal).
                  with("#{exception.backtrace[0]}: #{exception.message} (#{exception.class})")

                expect {perform}.to raise_error(exception)
              end
            end

          end

          describe '.perform' do
            let(:dummy) {Object.new}
            let(:perform) {described_class.perform(options)}

            it 'calls #perform on a new instance' do
              expect(described_class).
                to receive(:new).
                with(options).
                and_return(dummy)

              expect(dummy).to receive(:perform)

              perform
            end
          end

          context 'private API' do
            describe '#procedure' do
              let(:procedure) {workflow.instance_eval {procedure}}

              it 'must be defined in a subclass' do
                expect {procedure}.
                  to raise_error(
                    Undefined,
                    "You must define the private procedure method for your workflow."
                )
              end
            end

            describe '#task_name' do
              let(:task_name) {workflow.instance_eval {task_name}}

              it 'must be defined in a subclass' do
                expect {task_name}.
                  to raise_error(
                    Undefined,
                    "You must define the private task_name method for your workflow."
                )
              end
            end

            describe '#config' do
              it 'is a Deploy Configuration for our options' do
                expect(EY::Serverside::Deploy::Configuration).
                  to receive(:new).
                  with(options).
                  and_return(config)

                expect(workflow.instance_eval {config}).to eql(config)
              end
            end

            describe '#shell' do
              before(:each) do
                allow(config).to receive(:app).and_return('denied')
                allow(workflow).to receive(:task_name).and_return('george')
              end

              it 'is a Shell' do
                expect(EY::Serverside::Shell).
                  to receive(:new).
                  with(
                    :verbose => config.verbose,
                    :log_path => File.join(
                      ENV['HOME'],
                      "#{config.app}-#{workflow.instance_eval {task_name}}.log"
                    )
                  ).
                  and_return(shell)

                expect(workflow.instance_eval {shell}).to eql(shell)
              end
            end

            describe '#servers' do
              let(:server_hashes) {[]}
              let(:collection) {Object.new}
              let(:servers) {workflow.instance_eval {servers}}

              before(:each) do
                allow(workflow).to receive(:task_name)
              end

              it 'is the servers applicable to the workflow' do
                expect(EY::Serverside::CLI::ServerHashExtractor).
                  to receive(:hashes).
                  with(options, config).
                  and_return(server_hashes)

                expect(EY::Serverside::Servers).
                  to receive(:from_hashes).
                  with(server_hashes, shell).
                  and_return(collection)

                expect(servers).to eql(collection)
              end
            end

            describe '#propagate_serverside' do
              let(:servers) {Object.new}

              let(:propagate_serverside) {
                workflow.instance_eval {propagate_serverside}
              }

              before(:each) do
                allow(workflow).to receive(:task_name)
              end

              it 'propagates engineyard-serverside to the workflow servers' do
                expect(workflow).to receive(:servers).and_return(servers)

                expect(EY::Serverside::Propagator).
                  to receive(:propagate).
                  with(servers, shell)

                propagate_serverside
              end
            end



          end

        end
      end
    end
  end
end
