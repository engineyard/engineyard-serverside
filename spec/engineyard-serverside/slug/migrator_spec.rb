require 'spec_helper'

require 'result'
require 'engineyard-serverside/slug/migrator'

module EY
  module Serverside
    module Slug

      describe Migrator do
        let(:release_name) {'123456789'}
        let(:app_name) {'george'}
        let(:paths) {Object.new}
        let(:servers) {[]}
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

        let(:migrator) {described_class.new(config, shell)}

        describe '.migrate' do
          let(:migrator) {Object.new}
          let(:result) {success}
          let(:migrate) {described_class.migrate(data)}

          it 'calls a new instance' do
            expect(described_class).
              to receive(:new).
              with(config, shell).
              and_return(migrator)

            expect(migrator).to receive(:call).with(data).and_return(result)

            expect(migrate).to eql(success)
          end
        end

        describe '#call' do
          let(:binstubs) {"/path/to/binstubs"}
          let(:active_release) {"/path/to/active_release"}
          let(:framework_envs) {
            "RAILS_ENV=whatever MERB_ENV=whatever NODEJS_ENV=whatever"
          }
          let(:migration_command) {'rake db:migrate'}
          let(:cmd) {
            "PATH=#{binstubs}:$PATH #{framework_envs} #{migration_command}"
          }

          let(:result) {migrator.call(data)}

          before(:each) do
            allow(config).to receive(:paths).and_return(paths)
            allow(config).to receive(:framework_envs).and_return(framework_envs)
            allow(config).to receive(:migrate?).and_return(false)
            allow(config).
              to receive(:migration_command).
              and_return(migration_command)

            allow(paths).to receive(:binstubs).and_return(binstubs)
            allow(paths).to receive(:active_release).and_return(active_release)

            allow(Dir).to receive(:chdir).and_yield
            allow(migrator).to receive(:run_and_success?).and_return(false)
          end

          context 'when migrations are not requested' do
            before(:each) do
              allow(config).to receive(:migrate?).and_return(false)
            end

            it 'is a success' do
              expect(result).to be_a(Result::Success)
            end

            it 'does not modify its input' do
              expect(result.value).to eql(data)
            end
          end

          context 'when migrations are requested' do
            before(:each) do
              allow(config).to receive(:migrate?).and_return(true)
              expect(Dir).to receive(:chdir).with(active_release).and_yield
            end

            context 'but the migration command fails' do
              before(:each) do
                allow(migrator).
                  to receive(:run_and_success?).
                  with(cmd).
                  and_return(false)
              end

              it 'is a failure' do
                expect(result).to be_a(Result::Failure)
              end

              it 'contains an error regarding the failed migration' do
                expect(result.error[:error]).
                  to eql("Could not migrate database")
              end
            end

            context 'and the migration command succeeds' do
              before(:each) do
                allow(migrator).
                  to receive(:run_and_success?).
                  with(cmd).
                  and_return(true)
              end

              it 'is a success' do
                expect(result).to be_a(Result::Success)
              end

              it 'records the successful migration' do
                expect(result.value[:migrated]).to eql(true)
              end
            end
          end
        end

      end
    end
  end
end
