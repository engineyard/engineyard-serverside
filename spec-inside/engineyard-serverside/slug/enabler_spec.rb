require 'ostruct'

require 'spec_helper'

require 'result'
require 'engineyard-serverside/slug/enabler'

module EY
  module Serverside
    module Slug

      describe Enabler do
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

        let(:app) {
          OpenStruct.new(
            :hostname => 'server2',
            :role => :app,
            :user => 'deployapp'
          )
        }

        let(:util) {
          OpenStruct.new(
            :hostname => 'server1',
            :role => :util,
            :user => 'deployutil'
          )
        }

        let(:servers) {[app_master, app, util]}

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

        let(:enabler) {described_class.new(config, shell, servers)}

        before(:each) do
          allow(config).to receive(:paths).and_return(paths)

          allow(paths).to receive(:internal_key).and_return(internal_key)
        end

        it 'is a Railway' do
          expect(enabler).to be_a(Railway)
        end

        it 'has the exact steps for distributing a packaged app' do
          steps = described_class.steps.map {|s| s[:name]}

          expect(steps).to eql(
            [
              :enable_remotes,
              :enable_local
            ]
          )
        end

        describe '#enable_remotes' do
          let(:remotes) {[app, util]}
          let(:result) {enabler.send(:enable_remotes, data)}

          before(:each) do
            remotes.each do |remote|
              allow(enabler).
                to receive(:run_and_success?).
                with(enabler.send(:remote_command, remote, data)).
                and_return(true)
            end
          end

          it 'executes the enable command for each remote' do
            remotes.each do |remote|
              expect(enabler).
                to receive(:run_and_success?).
                with(enabler.send(:remote_command, remote, data)).
                and_return(true)
            end

            result
          end

          context 'when any execution fails' do
            before(:each) do
              expect(enabler).
                to receive(:run_and_success?).
                with(enabler.send(:remote_command, app, data)).
                and_return(false)

              expect(enabler).
                not_to receive(:run_and_success?).
                with(enabler.send(:remote_command, util, data))
            end

            it 'is a failure' do
              expect(result).to be_a(Result::Failure)
            end

            it 'records the enabling error' do
              expect(result.error[:error]).
                to eql("Could not enable #{release_name} on #{app.hostname}")
            end
          end

          context 'when all executions succeed' do
            it 'is a success' do
              expect(result).to be_a(Result::Success)
            end

            it 'records the successfully enabled servers' do
              expect(result.value[:enabled]).to include(app)
              expect(result.value[:enabled]).to include(util)
            end
          end
        end

        describe '#enable_local' do
          let(:local_data) {data.merge(:enabled => [app, util])}
          let(:result) {enabler.send(:enable_local, local_data)}

          it 'runs the local enable command' do
            expect(enabler).
              to receive(:run_and_success?).
              with(enabler.send(:local_command, data))

            result
          end

          context 'when execution fails' do
            before(:each) do
              allow(enabler).
                to receive(:run_and_success?).
                with(enabler.send(:local_command, data)).
                and_return(false)
            end

            it 'is a failure' do
              expect(result).to be_a(Result::Failure)
            end

            it 'records the error' do
              expect(result.error[:error]).to eql("Could not enable #{release_name} on the app master")
            end
          end

          context 'when execution succeeds' do
            before(:each) do
              allow(enabler).
                to receive(:run_and_success?).
                with(enabler.send(:local_command, data)).
                and_return(true)
            end

            it 'is a success' do
              expect(result).to be_a(Result::Success)
            end

            it 'adds the app master to the enabled list' do
              expect(result.value[:enabled]).to include(app_master)
            end
          end
        end


      end
    end
  end
end
