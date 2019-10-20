require 'spec_helper'
require 'escape'

require 'result'

require 'engineyard-serverside/callbacks/executor/executable'

module EY
  module Serverside
    module Callbacks
      module Executor

        describe Executable do
          let(:config) {Object.new}
          let(:shell) {Object.new}
          let(:paths) {Object.new}
          let(:hook) {Object.new}
          let(:short_name) {'hook'}
          let(:active_release_path) {'/path/to/the/active/release'}
          let(:hook_path) {'/path/to/the/dang/hook'}
          let(:account_name) {'george'}
          let(:app) {'tacoma'}
          let(:env_name) {'gracie'}
          let(:framework_env) {'sausages'}
          let(:current_roles) {['hamlet', 'ophelia']}
          let(:current_name) {nil}
          let(:config_json) {'a big ol hash'}
          let(:verbose) {false}
          let(:execution_success) {true}

          let(:executor) {described_class.new(config, shell, hook)}

          before(:each) do
            allow(hook).to receive(:path).and_return(hook_path)
            allow(hook).to receive(:short_name).and_return(short_name)
            allow(hook).
              to receive(:respond_to?).
              with(:service_name).
              and_return(false)

            allow(shell).to receive(:info)
            allow(shell).to receive(:fatal)
            allow(shell).to receive(:warning)

            allow(config).to receive(:paths).and_return(paths)
            allow(config).to receive(:current_roles).and_return(current_roles)
            allow(config).to receive(:account_name).and_return(account_name)
            allow(config).to receive(:app).and_return(app)
            allow(config).to receive(:environment_name).and_return(env_name)
            allow(config).to receive(:verbose).and_return(verbose)
            allow(config).to receive(:current_name).and_return(current_name)
            allow(config).to receive(:framework_env).and_return(framework_env)
            allow(config).to receive(:to_json).and_return(config_json)
            allow(config).
              to receive(:framework_envs).
              and_return("RACK_ENV=#{framework_env} RAILS_ENV=#{framework_env}")


            allow(paths).to receive(:active_release).and_return(active_release_path)
            allow(hook_path).to receive(:executable?).and_return(true)

            # This is a wee bit dirty, but the easiest way to test our actual code
            # here is to stub out the included Runner interface.
            allow(executor).to receive(:run) do |cmd|
              EY::Serverside::Spawner::Result.new(cmd, execution_success, cmd, nil)
            end

            # We also need to stub out the #abort method, as we don't need the
            # test suite to just up and stop running when we test executor failure
            # modes.
            allow(executor).to receive(:abort)
          end

          it 'is a Railway' do
            expect(executor).to be_a(Railway)
          end

          it 'knows how to spawn CLI processes' do
            expect(executor).to be_a(Runner)
          end

          it 'has the exact steps for executing a Ruby hook' do
            steps = described_class.steps.map {|s| s[:name]}

            expect(steps).to eql(
              [
                :validate_hook,
                :populate_environment,
                :calculate_wrapper,
                :run_hook
              ]
            )
          end

          describe '#validate_hook' do
            let(:input) {
              {}
            }

            let(:result) {executor.validate_hook}

            context 'when the hook has the executable bit' do
              before(:each) do
                allow(hook_path).to receive(:executable?).and_return(true)
              end

              it 'is a Success' do
                expect(result).to be_a(Result::Success)
              end

              it 'does not alter the input' do
                expect(result.value).to eql(input)
              end
            end

            context 'when the hook lacks the executable bit' do
              before(:each) do
                allow(hook_path).to receive(:executable?).and_return(false)
              end

              it 'is a Failure' do
                expect(result).to be_a(Result::Failure)
              end

              it 'contains a reason for the failure' do
                expect(result.error[:reason]).to eql(:not_executable)
              end
            end
          end

          describe '#populate_environment' do
            let(:input) {{}}

            let(:result) {executor.populate_environment(input)}
            let(:result_env) {result.value[:environment]}

            it 'is a Success' do
              expect(result).to be_a(Result::Success)
            end

            it 'adds the environment to the input' do
              expect(result_env).to be_a(String)
            end

            it 'includes the account name in the environment' do
              escaped = Escape.shell_command([account_name])

              expect(result_env).
                to match(%r{EY_DEPLOY_ACCOUNT_NAME=#{escaped}})
            end

            it 'includes the application in the environment' do
              escaped = Escape.shell_command([app])

              expect(result_env).
                to match(%{EY_DEPLOY_APP=#{escaped}})
            end

            it 'includes the JSON representation of the config in the environment' do
              escaped = Escape.shell_command([config_json])

              expect(result_env).
                to match(%r{EY_DEPLOY_CONFIG=#{escaped}})
            end

            it 'includes all of the current roles in the environment' do
              expect(result_env).
                to match(%r{EY_DEPLOY_CURRENT_ROLES='#{current_roles.join(' ')}'})
            end

            context 'when the server is named' do
              let(:current_name) {'frankie'}
              let(:escaped) {Escape.shell_command([current_name])}

              it 'includes the current server name' do
                expect(result_env).
                  to match(%r{EY_DEPLOY_CURRENT_NAME=#{escaped}})
              end
            end

            context 'when the server is unnamed' do
              let(:current_name) {nil}

              it 'omits the current server name' do
                expect(result_env).
                  not_to match(%r{EY_DEPLOY_CURRENT_NAME})
              end
            end

            it 'includes the environment name in the environment' do
              escaped = Escape.shell_command([env_name])

              expect(result_env).
                to match(%r{EY_DEPLOY_ENVIRONMENT_NAME=#{escaped}})
            end

            it 'includes the framwork env in the environment' do
              escaped = Escape.shell_command([framework_env])

              expect(result_env).
                to match(%r{EY_DEPLOY_FRAMEWORK_ENV=#{escaped}})
            end

            it 'includes the release path in the environment' do
              escaped = Escape.shell_command([active_release_path])

              expect(result_env).
                to match(%r{EY_DEPLOY_RELEASE_PATH=#{escaped}})
            end

            context 'with verbosity configured' do
              let(:verbose) {true}

              it 'enables verbosity in the environment' do
                expect(result.value[:environment]).
                  to match(%r{EY_DEPLOY_VERBOSE=1})
              end
            end

            context 'without verbosity configured' do
              let(:verbose) {false}

              it 'disables verbosity in the environment' do
                expect(result.value[:environment]).
                  to match(%r{EY_DEPLOY_VERBOSE=0})
              end
            end

            context 'when any of the values involved are nil' do
              let(:account_name) {nil}
              let(:app) {nil}
              let(:config_json) {nil}
              let(:env_name) {nil}

              it 'omits those env vars' do
                affected = ['ACCOUNT_NAME', 'APP', 'CONFIG', 'ENVIRONMENT_NAME']

                affected.each do |var|
                  expect(result_env).not_to match(%r{EY_DEPLOY_#{var}})
                end
              end

            end

          end

          describe '#calculate_wrapper' do
            let(:input) {{}}

            let(:result) {executor.calculate_wrapper(input)}

            it 'is a Success' do
              expect(result).to be_a(Result::Success)
            end

            it 'adds a wrapper to the input' do
              expect(result.value[:wrapper]).not_to be_nil
            end

            context 'when dealing with a service hook' do
              before(:each) do
                allow(hook).
                  to receive(:respond_to?).
                  with(:service_name).
                  and_return(true)
              end

              it 'wraps the service hook executor' do
                expect(result.value[:wrapper]).to eql(About.service_hook_executor)
              end
            end

            context 'when dealing with an app hook' do
              before(:each) do
                allow(hook).
                  to receive(:respond_to?).
                  with(:service_name).
                  and_return(false)
              end

              it 'wraps the app hook executor' do
                expect(result.value[:wrapper]).to eql(About.hook_executor)
              end
            end
          end

          describe '#run_hook' do
            let(:dummy_env) {'i am an environment'}
            let(:wrapper) {'candy-bar'}
            let(:input) {
              {
                :wrapper => wrapper,
                :environment => dummy_env
              }
            }

            let(:result) {executor.run_hook(input)}

            it 'runs the proper command' do
              expect(executor).
                to receive(:run).
                with(
                  "#{dummy_env} #{config.framework_envs} #{wrapper} #{short_name}"
                )

              result
            end

            context 'when the execution succeeds' do
              let(:execution_success) {true}

              it 'is a Success' do
                expect(result).to be_a(Result::Success)
              end

              it 'does not alter the input' do
                expect(result.value).to eql(input)
              end
            end

            context 'when the execution fails' do
              let(:execution_success) {false}

              it 'is a Failure' do
                expect(result).to be_a(Result::Failure)
              end

              it 'has exeuction failure as its reason' do
                expect(result.error[:reason]).to eql(:execution_failed)
              end
            end
          end

          describe '#handle_failure' do
            let(:reason) {nil}
            let(:error) {
              {
                :reason => reason
              }
            }

            let(:result) {executor.handle_failure(error)}

            context 'when the hook is not actually executable' do
              let(:reason) {:not_executable}

              it 'aborts with a message about the bad hook' do
                expect(executor).
                  to receive(:abort).
                  with(
                    "*** [Error] Hook is not executable: #{hook_path} ***\n"
                  )

                result
              end
            end

            context 'when execution of the hook fails' do
              let(:reason) {:execution_failed}

              it 'aborts with a message about the execution failure' do
                expect(executor).
                  to receive(:abort).
                  with(
                    "*** [Error] Hook failed to exit cleanly: #{hook_path} ***\n"
                  )

                result
              end
            end

            context 'when an otherwise unexpected error occurs' do
              let(:reason) {nil}

              it 'aborts with a message about the unknown error' do
                expect(executor).
                  to receive(:abort).
                  with("*** [Error] An unknown error occurred for hook: #{hook_path} ***\n")

                result
              end
            end
          end

        end

      end
    end
  end
end
