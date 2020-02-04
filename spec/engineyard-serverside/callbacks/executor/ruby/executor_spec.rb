require 'spec_helper'

require 'result'

require 'engineyard-serverside/callbacks/executor/ruby/executor'

module EY
  module Serverside
    module Callbacks
      module Executor

        module Ruby
          describe Executor do
            let(:config) {Object.new}
            let(:shell) {Object.new}
            let(:paths) {Object.new}
            let(:hook) {Object.new}
            let(:active_release_path) {'/path/to/the/active/release'}
            let(:hook_path) {'/path/to/the/dang/hook.rb'}
            let(:hook_content) {
              'puts "My sausages turned to gold!"'
            }
            let(:syntax_error) {'OMG what bad syntax'}

            let(:executor) {described_class.new(config, shell, hook)}

            before(:each) do
              allow(hook).to receive(:path).and_return(hook_path)
              allow(hook).to receive(:read).and_return(hook_content)

              allow(shell).to receive(:info)
              allow(shell).to receive(:fatal)
              allow(shell).to receive(:warning)

              allow(config).to receive(:paths).and_return(paths)

              allow(paths).to receive(:active_release).and_return(active_release_path)
            end

            it 'is a Railway' do
              expect(executor).to be_a(Railway)
            end

            it 'has the exact steps for executing a Ruby hook' do
              steps = described_class.steps.map {|s| s[:name]}

              expect(steps).to eql(
                [
                  :validate_hook,
                  :display_deprecation_warnings,
                  :announce_execution,
                  :context_eval
                ]
              )
            end

            describe '#validate_hook' do
              let(:input) {
                {}
              }

              let(:result) {executor.validate_hook}

              context 'when ruby reports good syntax' do
                before(:each) do
                  allow(executor).
                    to receive(:`).
                    and_return('Syntax OK')
                end

                it 'is a Success' do
                  expect(result).to be_a(Result::Success)
                end

                it 'contains the hook code' do
                  expect(result.value[:code]).to eql(hook_content)
                end
              end

              context 'when ruby reports bad syntax' do
                before(:each) do
                  allow(executor).
                    to receive(:`).
                    and_return(syntax_error)
                end

                it 'is a failure' do
                  expect(result).to be_a(Result::Failure)
                end

                it 'the reason for the failure is a syntax error' do
                  expect(result.error[:reason]).to eql(:syntax_error)
                end

                it 'contains the actual syntax error' do
                  expect(result.error[:syntax_error]).to eql(syntax_error)
                end

              end
            end

            describe '#display_deprecation_warnings' do
              let(:input) {
                {
                  :code => hook_content
                }
              }

              let(:result) {executor.display_deprecation_warnings(input)}

              context 'when there are @configuration references in the hook' do
                let(:hook_content) {'@configuration == "my jam"'}
                let(:warning_message) {
                  "Use of `@configuration` in deploy hooks is deprecated.\nPlease use `config`, which provides access to the same object.\n\tin #{hook_path}"
                }

                it 'prints a warning regarding that usage' do
                  expect(shell).
                    to receive(:warning).
                    with(warning_message)

                  result
                end
              end

              context 'when there are @node references in the hook' do
                let(:hook_content) {'@node == "my jam"'}
                let(:warning_message) {
                  "Use of `@node` in deploy hooks is deprecated.\nPlease use `config.node`, which provides access to the same object.\n\tin #{hook_path}"
                }

                it 'prints a warning regarding that usage' do
                  expect(shell).
                    to receive(:warning).
                    with(warning_message)

                  result
                end
              end

              it 'is a Success' do
                expect(result).to be_a(Result::Success)
              end

              it 'does not alter the input' do
                expect(result.value).to eql(input)
              end

            end

            describe '#announce_execution' do
              let(:input) {
                {
                  :code => hook_content
                }
              }

              let(:result) {executor.announce_execution(input)}

              it 'lets the user know that the hook is being executed' do
                expect(shell).to receive(:info).with("Executing #{hook_path} ...")

                result
              end

              it 'is a Success' do
                expect(result).to be_a(Result::Success)
              end

              it 'does not alter the input' do
                expect(result.value).to eql(input)
              end
            end

            describe '#context_eval' do
              let(:ruby_context) {Object.new}
              let(:input) {
                {
                  :code => hook_content
                }
              }

              let(:result) {executor.context_eval(input)}

              before(:each) do
                allow(Dir).to receive(:chdir).and_yield

                allow(Context).
                  to receive(:new).
                  and_return(ruby_context)

                allow(ruby_context).to receive(:instance_eval)
              end

              it 'switches to the active release directory' do
                expect(Dir).to receive(:chdir).with(active_release_path).and_yield

                result
              end

              it 'attempts to execute the hook via a new context' do
                expect(ruby_context).to receive(:instance_eval).with(hook_content)

                result
              end

              context 'when the hook executes without issue' do
                it 'is a Success' do
                  expect(result).to be_a(Result::Success)
                end

                it 'does not modify its input' do
                  expect(result.value).to eql(input)
                end
              end

              context 'when the hook raises an exception' do
                let(:exception_message) {'nine kinds of calamity'}

                before(:each) do
                  allow(ruby_context).
                    to receive(:instance_eval).
                    with(hook_content).
                    and_raise(exception_message)
                end

                it 'is a Failure' do
                  expect(result).to be_a(Result::Failure)
                end

                it 'has a failed execution reason' do
                  expect(result.error[:reason]).to eql(:execution_failed)
                end

                it 'includes the raised exception' do
                  expect(result.error[:exception].to_s).
                    to eql(exception_message)
                end
              end
            end

            describe '#handle_failure' do
              let(:reason) {nil}
              let(:exception) {nil}

              let(:payload) {
                {
                  :code => hook_content,
                  :reason => reason,
                  :exception => exception,
                  :syntax_error => syntax_error
                }
              }

              let(:result) {executor.handle_failure(payload)}

              before(:each) do
                allow(executor).to receive(:abort)
              end

              context 'when the failure was due to a failed execution' do
                let(:exception_message) {'cats have cute little nosies'}
                let(:exception) {RuntimeError.new(exception_message)}
                let(:reason) {:execution_failed}

                it 'logs the exception' do
                  expect(shell).to receive(:fatal).with("  Exception raised in hook #{hook_path}.\n\n  RuntimeError: #{exception_message}\n\n  Please fix this error before retrying.\n")

                  begin
                    result
                  rescue
                  end
                end

                it 're-raises the exception' do
                  expect {result}.to raise_exception(exception)
                end
              end

              context 'when the failure was due to a syntax error' do
                let(:reason) {:syntax_error}
                let(:abort_message) {
                  "*** [Error] Invalid Ruby syntax in hook: #{hook_path} ***\n*** #{syntax_error} ***"
                }

                it 'aborts with a message regarding the syntax error' do
                  expect(executor).to receive(:abort).with(abort_message)

                  result
                end
              end

              context 'when the failure was due to some unknown problem' do
                let(:reason) {nil}
                let(:abort_message) {
                  "*** [Error] An unknown error occurred for hook: #{hook_path} ***"
                }

                it 'abors with a message regarding the unknown error' do
                  expect(executor).to receive(:abort).with(abort_message)

                  result
                end

              end
            end
          end

        end
      end
    end
  end
end
