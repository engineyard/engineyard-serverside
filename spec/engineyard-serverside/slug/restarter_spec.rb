require 'ostruct'

require 'spec_helper'

require 'result'
require 'engineyard-serverside/slug/restarter'

module EY
  module Serverside
    module Slug

      describe Restarter do
        let(:release_name) {'123456789'}
        let(:app_name) {'george'}
        let(:internal_key) {'/path/to/internal/key'}
        let(:paths) {Object.new}

        let(:app_master) {
          OpenStruct.new(
            :hostname => 'server1',
            :role => :app_master,
            :user => 'deploy'
          )
        }

        let(:app1) {
          OpenStruct.new(
            :hostname => 'server2',
            :role => :app,
            :user => 'deployapp'
          )
        }

        let(:app2) {
          OpenStruct.new(
            :hostname => 'server3',
            :role => :app,
            :user => 'deployapp'
          )
        }


        let(:util) {
          OpenStruct.new(
            :hostname => 'server4',
            :role => :util,
            :user => 'deployutil'
          )
        }

        let(:servers) {[app_master, app1, app2, util]}

        let(:config) {Object.new}
        let(:shell) {Object.new}
        let(:success) {Result::Success.new(nil)}
        let(:failure) {Result::Failure.new(nil)}

        let(:data) {
          {
            :app_name => app_name,
            :release_name => release_name,
            :config => config,
            :shell => shell,
            :servers => servers
          }
        }

        let(:restarter) {described_class.new(config, shell, servers)}

        before(:each) do
          allow(config).to receive(:paths).and_return(paths)

          allow(paths).to receive(:internal_key).and_return(internal_key)
        end

        it 'is a Railway' do
          expect(restarter).to be_a(Railway)
        end

        it 'is a Runner' do
          expect(restarter).to be_a(Runner)
        end

        it 'has the exact steps for restartingting a packaged app' do
          steps = described_class.steps.map {|s| s[:name]}

          expect(steps).to eql(
            [
              :restart_remote_apps,
              :restart_local
            ]
          )
        end

        describe '.restart' do
          let(:restarter) {Object.new}

          it 'restarts via a new instance' do
            expect(described_class).
              to receive(:new).
              with(config, shell, servers).
              and_return(restarter)

            expect(restarter).to receive(:call).with(data).and_return(success)

            described_class.restart(data)
          end
        end

        describe '#restart_remote_apps' do
          let(:remote_apps) {[app1, app2]}
          let(:result) {restarter.send(:restart_remote_apps, data)}

          before(:each) do
            remote_apps.each do |remote|
              allow(restarter).
                to receive(:run_and_success?).
                with(restarter.send(:remote_command, remote, data)).
                and_return(true)
            end
          end

          it 'executes the enable command for each app remote' do
            remote_apps.each do |remote|
              expect(restarter).
                to receive(:run_and_success?).
                with(restarter.send(:remote_command, remote, data)).
                and_return(true)
            end

            result
          end

          it 'omits utility instances from restart' do
            expect(restarter).
              not_to receive(:run_and_success?).
              with(restarter.send(:remote_command, util, data))

            result
          end

          context 'when any execution fails' do
            before(:each) do
              allow(restarter).
                to receive(:run_and_success?).
                with(restarter.send(:remote_command, app2, data)).
                and_return(false)
            end

            it 'is a failure' do
              expect(result).to be_a(Result::Failure)
            end

            it 'records the restart error' do
              expect(result.error[:error]).
                to eql("Could not restart #{release_name} on #{app2.hostname}")
            end

            it 'records any servers that were successfully restarted' do
              expect(result.error[:restarted]).to include(app1)
            end
          end

          context 'when all executions succeed' do
            it 'is a success' do
              expect(result).to be_a(Result::Success)
            end

            it 'records the successfully restarted servers' do
              expect(result.value[:restarted]).to include(app1)
              expect(result.value[:restarted]).to include(app2)
            end
          end
        end

        describe '#restart_local' do
          let(:local_data) {data.merge(:restarted => [app1, app2])}
          let(:result) {restarter.send(:restart_local, local_data)}

          it 'runs the local restart command' do
            expect(restarter).
              to receive(:run_and_success?).
              with(restarter.send(:restart_command, local_data))

            result
          end

          context 'when execution fails' do
            before(:each) do
              allow(restarter).
                to receive(:run_and_success?).
                with(restarter.send(:restart_command, local_data)).
                and_return(false)
            end

            it 'is a failure' do
              expect(result).to be_a(Result::Failure)
            end

            it 'records the error' do
              expect(result.error[:error]).to eql("Could not restart #{release_name} on the app master")
            end
          end

          context 'when execution succeeds' do
            before(:each) do
              allow(restarter).
                to receive(:run_and_success?).
                with(restarter.send(:restart_command, local_data)).
                and_return(true)
            end

            it 'is a success' do
              expect(result).to be_a(Result::Success)
            end

            it 'adds the app master to the enabled list' do
              expect(result.value[:restarted]).to include(app_master)
            end
          end
        end

      end
    end
  end
end
