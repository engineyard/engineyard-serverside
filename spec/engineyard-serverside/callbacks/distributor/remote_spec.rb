require 'spec_helper'

require 'pathname'
require 'escape'

require 'engineyard-serverside/callbacks/distributor/remote'

module EY
  module Serverside
    module Callbacks
      module Distributor

        describe Remote do
          let(:runner) {Object.new}
          let(:callback_name) {:some_callback}
          let(:shell) {Object.new}
          let(:config) {Object.new}
          let(:paths) {Object.new}
          let(:app) {'some_app'}
          let(:account_name) {'some_account'}
          let(:config_json) {'i am a json config'}
          let(:environment_name) {'some_environment'}
          let(:framework_env) {'some_framework_env'}
          let(:verbose) {nil}
          let(:active_release) {'/data/some_app/releases/123456789'}
          let(:server) {Object.new}
          let(:server_name) {nil}
          let(:roles) {[:hamlet, :ophelia]}
          let(:cmd) {'some command'}

          let(:distributor) {described_class.new(runner, callback_name)}

          before(:each) do
            # Stub out the parts of the runner interface that we use
            allow(runner).to receive(:shell).and_return(shell)
            allow(runner).to receive(:run).and_yield(server, cmd)
            allow(runner).to receive(:config).and_return(config)
            allow(runner).to receive(:paths).and_return(paths)

            # Stub out the parts of the shell interface that we use
            allow(shell).to receive(:status)

            # Stub out the parts of the config interface that we use
            allow(config).to receive(:account_name).and_return(account_name)
            allow(config).to receive(:app).and_return(app)
            allow(config).
              to receive(:environment_name).
              and_return(environment_name)
            allow(config).to receive(:framework_env).and_return(framework_env)
            allow(config).to receive(:to_json).and_return(config_json)
            allow(config).to receive(:verbose).and_return(verbose)

            # Stub out the parts of the paths interface that we use
            allow(paths).to receive(:active_release).and_return(active_release)

            # Stub out the parts of the server interface that we use
            allow(server).to receive(:roles).and_return(roles)
            allow(server).to receive(:name).and_return(server_name)
          end

          describe '.distribute' do
            let(:result) {described_class.distribute(runner, callback_name)}

            it 'uses a new distributor to distribute the hook' do
              distributor = Object.new

              expect(described_class).
                to receive(:new).
                with(runner, callback_name).
                and_return(distributor)

              expect(distributor).to receive(:distribute)

              result
            end
          end

          describe '#distribute' do
            let(:result) {distributor.distribute}

            it 'runs the escaped command for the callback' do
              escaped_command = 'i am an escaped command'

              expect(distributor).
                to receive(:escaped_command).
                and_return(escaped_command)

              expect(runner).
                to receive(:run).
                with(escaped_command).
                and_yield(server, escaped_command)

              result
            end

            it 'announces that the hook is being run' do
              expect(shell).
                to receive(:status).
                with("Running deploy hook: #{callback_name}")

              result
            end

            it 'adds the escaped current roles flag' do
              expect(result).to match(/--current-roles 'hamlet ophelia'/)
            end

            it 'adds the escaped config flag' do
              expect(result).to match(/--config '#{config_json}'/)
            end

            context 'when the server has a name' do
              let(:server_name) {'frank'}

              it 'adds the current name flag' do
                expect(result).to match(/--current-name #{server_name}/)
              end
            end

            context 'when the server has a name' do
              let(:server_name) {nil}

              it 'omits the current name flag' do
                expect(result).not_to match(/--current-name/)
              end
            end

          end
        end

      end
    end
  end
end

