require 'spec_helper'

require 'escape'

require 'engineyard-serverside/callbacks/executor/ruby/context'

module EY
  module Serverside
    module Callbacks
      module Executor
        module Ruby

          describe Context do
            let(:config) {
              Class.new do
                def two_minus_one
                  1
                end
              end.new
            }

            let(:shell) {Object.new}
            let(:paths) {Object.new}
            let(:hook) {Object.new}
            let(:hook_path) {'/path/to/the/dang/hook.rb'}
            let(:current_roles) {['hamlet', 'ophelia']}
            let(:node) {Object.new}
            let(:active_release_path) {'/path/to/the/release'}
            let(:execution_success) {true}

            let(:context) {described_class.new(config, shell, hook)}

            before(:each) do
              allow(hook).to receive(:path).and_return(hook_path)

              allow(shell).to receive(:info)
              allow(shell).to receive(:fatal)
              allow(shell).to receive(:warning)
              allow(shell).to receive(:logged_system) do |cmd|
                EY::Serverside::Spawner::Result.new(
                  cmd,
                  execution_success,
                  cmd,
                  nil
                )
              end

              allow(config).to receive(:paths).and_return(paths)
              allow(config).to receive(:set_framework_envs)
              allow(config).to receive(:node).and_return(node)
              allow(config).to receive(:current_roles).and_return(current_roles)

              allow(paths).
                to receive(:active_release).
                and_return(active_release_path)
            end

            describe '#inspect' do
              let(:result) {context.inspect}

              it 'is a string' do
                expect(result).to be_a(String)
              end

              it 'includes the context namespace path' do
                expect(result).to match(%r{Callbacks::Executor::Ruby::Context})
              end

              it 'includes the path to the hook' do
                expect(result).to match(%{#{hook_path.inspect}})
              end

              it 'looks like a typical inspect result' do
                expect(result).to match(%{^#<.*>$})
              end
            end

            describe '#config' do
              it 'is the configuration object for the context' do
                expect(context.config).to eql(context.config)
              end
            end

            describe '#method_missing' do
              context 'for config methods' do
                let(:result) {context.two_minus_one}

                it 'warns about deprecated missing_method reliance' do
                  expect(shell).to receive(:warning).with("Use of `two_minus_one` (via method_missing) is deprecated in favor of `config.two_minus_one` for improved error messages and compatibility.\n\tin #{hook_path}")

                  result
                end

                it 'passes the call along to config' do
                  expect(config).to receive(:two_minus_one).and_return(3)

                  expect(result).to eql(3)
                end
              end

              context 'for non-config methods' do
                let(:result) {context.two_minus_two}

                it 'eventually raises an error' do
                  expect {result}.to raise_error
                end

              end
            end

            describe '#respond_to?' do
              let(:meth) {:class}

              let(:result) {context.respond_to?(meth)}

              context 'when given a config method' do
                let(:meth) {:two_minus_one}

                it 'is true' do
                  expect(result).to eql(true)
                end
              end

              context 'when given a non-config method' do
                context 'that context knows how to handle' do
                  let(:meth) {:run}

                  it 'is true' do
                    expect(result).to eql(true)
                  end
                end

                context 'that context does not know how to handle' do
                  let(:meth) {:walk}

                  it 'is false' do
                    expect(result).to eql(false)
                  end
                end
              end
            end

            describe '#run' do
              let(:cmd) {'touch yournose'}
              let(:result) {context.run(cmd)}

              it 'runs the wrapped command via the shell with logging' do
                expect(shell).
                  to receive(:logged_system).
                  with("sh -l -c 'touch yournose'")

                result
              end

              context 'when the command succeeds' do
                let(:execution_success) {true}

                it 'is false' do
                  expect(result).to eql(true)
                end
              end

              context 'when the command fails' do
                let(:execution_success) {false}

                it 'is false' do
                  expect(result).to eql(false)
                end
              end
            end

            describe '#run!' do
              let(:cmd) {'touch yourtoes'}
              let(:result) {context.run!(cmd)}

              it 'runs the command' do
                expect(context).to receive(:run).with(cmd).and_return(true)

                result
              end

              context 'when the command succeeds' do
                let(:execution_success) {true}

                it 'is true' do
                  expect(result).to eql(true)
                end
              end

              context 'when the command fails' do
                let(:execution_success) {false}

                it 'raises an error' do
                  expect {result}.to raise_error("run!: Command failed. #{cmd}")
                end
              end
            end

            describe '#sudo' do
              let(:cmd) {'touch yournose'}
              let(:result) {context.sudo(cmd)}

              it 'runs the sudo-wrapped command via the shell with logging' do
                expect(shell).
                  to receive(:logged_system).
                  with("sudo sh -l -c 'touch yournose'")

                result
              end

              context 'when the command succeeds' do
                let(:execution_success) {true}

                it 'is false' do
                  expect(result).to eql(true)
                end
              end

              context 'when the command fails' do
                let(:execution_success) {false}

                it 'is false' do
                  expect(result).to eql(false)
                end
              end
            end


            describe '#sudo!' do
              let(:cmd) {'touch yourtoes'}
              let(:result) {context.sudo!(cmd)}

              it 'sudo runs the command' do
                expect(context).to receive(:sudo).with(cmd).and_return(true)

                result
              end

              context 'when the command succeeds' do
                let(:execution_success) {true}

                it 'is true' do
                  expect(result).to eql(true)
                end
              end

              context 'when the command fails' do
                let(:execution_success) {false}

                it 'raises an error' do
                  expect {result}.to raise_error("sudo!: Command failed. #{cmd}")
                end
              end
            end

            describe '#on_app_master' do
              let(:dummy) {Object.new}
              let(:result) {context.on_app_master {dummy.process}}

              before(:each) do
                allow(dummy).to receive(:process)
              end

              context 'on a solo instance' do
                let(:current_roles) {['solo']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on an app master instance' do
                let(:current_roles) {['app_master']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on an app instance' do
                let(:current_roles) {['app']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a util instance' do
                let(:current_roles) {['util']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a database master instance' do
                let(:current_roles) {['db_master']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a database replicant instance' do
                let(:current_roles) {['db_slave']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end
            end

            describe '#on_app_servers' do
              let(:dummy) {Object.new}
              let(:result) {context.on_app_servers {dummy.process}}

              before(:each) do
                allow(dummy).to receive(:process)
              end

              context 'on a solo instance' do
                let(:current_roles) {['solo']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on an app master instance' do
                let(:current_roles) {['app_master']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on an app instance' do
                let(:current_roles) {['app']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on a util instance' do
                let(:current_roles) {['util']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a database master instance' do
                let(:current_roles) {['db_master']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a database replicant instance' do
                let(:current_roles) {['db_slave']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end
            end

            describe '#on_app_servers_and_utilities' do
              let(:dummy) {Object.new}
              let(:result) {context.on_app_servers_and_utilities {dummy.process}}

              before(:each) do
                allow(dummy).to receive(:process)
              end

              context 'on a solo instance' do
                let(:current_roles) {['solo']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on an app master instance' do
                let(:current_roles) {['app_master']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on an app instance' do
                let(:current_roles) {['app']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on a util instance' do
                let(:current_roles) {['util']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on a database master instance' do
                let(:current_roles) {['db_master']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a database replicant instance' do
                let(:current_roles) {['db_slave']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end
            end

            describe '#on_utilities' do
              let(:dummy) {Object.new}
              let(:result) {context.on_utilities {dummy.process}}

              before(:each) do
                allow(dummy).to receive(:process)
              end

              context 'on a solo instance' do
                let(:current_roles) {['solo']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on an app master instance' do
                let(:current_roles) {['app_master']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on an app instance' do
                let(:current_roles) {['app']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a util instance' do
                let(:current_roles) {['util']}

                it 'runs the given block' do
                  expect(dummy).to receive(:process)

                  result
                end
              end

              context 'on a database master instance' do
                let(:current_roles) {['db_master']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

                  result
                end
              end

              context 'on a database replicant instance' do
                let(:current_roles) {['db_slave']}

                it 'skips the given block' do
                  expect(dummy).not_to receive(:process)

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
