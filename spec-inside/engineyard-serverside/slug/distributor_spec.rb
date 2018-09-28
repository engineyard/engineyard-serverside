require 'ostruct'

require 'spec_helper'

require 'result'
require 'engineyard-serverside/slug/distributor'

module EY
  module Serverside
    module Slug

      describe Distributor do
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

        let(:distributor) {described_class.new(config, shell, servers)}

        before(:each) do
          allow(config).to receive(:paths).and_return(paths)

          allow(paths).to receive(:internal_key).and_return(internal_key)
        end

        it 'is a Railway' do
          expect(distributor).to be_a(Railway)
        end

        it 'has the exact steps for distributing a packaged app' do
          steps = described_class.steps.map {|s| s[:name]}

          expect(steps).to eql(
            [
              :find_remotes,
              :distribute_to_remotes
            ]
          )
        end

        describe '.distribute' do
          let(:distributor) {Object.new}
          let(:result) {success}
          let(:distribute) {described_class.distribute(data)}

          it 'calls a new instance' do
            expect(described_class).
              to receive(:new).
              with(config, shell, servers).
              and_return(distributor)

            expect(distributor).to receive(:call).with(data).and_return(result)

            expect(distribute).to eql(success)
          end
        end

        describe '#find_remotes' do
          let(:find_remotes) {distributor.send(:find_remotes, data)}

          it 'is a success' do
            expect(find_remotes).to be_a(Result::Success)
          end

          it 'records the remotes in its output' do
            remotes = find_remotes.value[:remotes]
            expect(remotes).to include(app)
            expect(remotes).to include(util)
          end

          it 'omits app master from the remotes' do
            expect(find_remotes.value[:remotes]).not_to include(app_master)
          end
        end

        describe '#distribute_to_remotes' do
          let(:releases_path) {"/data/#{app_name}/releases"}
          let(:package) {"#{releases_path}/#{release_name}.tgz"}
          let(:remotes) {[app, util]}
          let(:distribute_input) {data.merge(:remotes => remotes)}

          let(:distribute) {
            distributor.send(:distribute_to_remotes, distribute_input)
          }

          before(:each) do
            remotes.each do |server|
              allow(distributor).
                to receive(:run_and_success?).
                with(
                  "scp -i #{internal_key} #{package} #{server.user}@#{server.hostname}:#{releases_path}"
                ).
                and_return(true)
            end
          end

          it 'copies the package to each remote' do
            remotes.each do |server|
              expect(distributor).
                to receive(:run_and_success?).
                with(
                  "scp -i #{internal_key} #{package} #{server.user}@#{server.hostname}:#{releases_path}"
                )
            end

            distribute
          end

          context 'when any copy process fails' do
            before(:each) do
              allow(distributor).
                to receive(:run_and_success?).
                with("scp -i #{internal_key} #{package} #{app.user}@#{app.hostname}:#{releases_path}").
                and_return(false)

              allow(distributor).
                to receive(:run_and_success?).
                with("scp -i #{internal_key} #{package} #{util.user}@#{util.hostname}:#{releases_path}").
                and_return(false)
            end

            it 'is a failure' do
              expect(distribute).to be_a(Result::Failure)
            end

            it 'records an error regarding the failed copies' do
              expect(distribute.error[:error]).to eql("Could not copy #{package} to #{app.hostname}")
            end
          end

          context 'when all copy processes succeed' do
            before(:each) do
              remotes.each do |server|
                allow(distributor).
                  to receive(:run_and_success?).
                  with(
                    "scp -i #{internal_key} #{package} #{server.user}@#{server.hostname}:#{releases_path}"
                  ).
                  and_return(true)
              end
            end

            it 'is a success' do
              expect(distribute).to be_a(Result::Success)
            end

            it 'does not modify its input' do
              expect(distribute.value).to eql(distribute_input)
            end
          end

        end

      end
    end
  end
end

