require 'ostruct'

require 'spec_helper'

require 'result'
require 'engineyard-serverside/slug/failure_handler'

module EY
  module Serverside
    module Slug

      describe FailureHandler do
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

        let(:handler) {described_class.new(config, shell, servers)}

        before(:each) do
          allow(config).to receive(:paths).and_return(paths)

          allow(paths).to receive(:internal_key).and_return(internal_key)
        end

        #it 'is a Railway' do
          #expect(handler).to be_a(Railway)
        #end

        #it 'has the exact steps for distributing a packaged app' do
          #steps = described_class.steps.map {|s| s[:name]}

          #expect(steps).to eql(
            #[
              #:handle_finalization_failure,
              #:handle_restart_failure,
              #:handle_enable_failure,
              #:handle_distribute_failure,
            #]
          #)
        #end

        describe '.handle' do
          let(:handler) {Object.new}

          it 'calls a new handler' do
            expect(described_class).
              to receive(:new).
              with(config, shell, servers).
              and_return(handler)

            expect(handler).to receive(:call).with(data).and_return(success)

            expect(described_class.handle(data)).to eql(success)
          end
        end

        describe '#call' do
          let(:result) {handler.call(data)}

          it 'is a failure' do
            expect(result).to be_a(Result::Failure)
          end

          it 'does not modify its input' do
            expect(result.error).to eql(data)
          end
        end
      end

    end
  end
end
