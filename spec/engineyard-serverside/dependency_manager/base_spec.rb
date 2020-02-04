require 'spec_helper'

require 'engineyard-serverside/dependency_manager/base'

module EY
  module Serverside
    class DependencyManager

      describe Base do
        let(:servers) {Object.new}
        let(:config) {Object.new}
        let(:shell) {Object.new}
        let(:runner) {Object.new}

        let(:manager) {described_class.new(servers, config, shell, runner)}

        describe '.detect' do
          let(:manager) {Object.new}
          let(:detected) {false}
          let(:result) {described_class.detect(servers, config, shell, runner)}

          before(:each) do
            allow(described_class).to receive(:new).and_return(manager)
            allow(manager).to receive(:detected?).and_return(detected)
          end

          context 'when the manager can detect its dependency signature' do
            let(:detected) {true}

            it 'is a new instance of the class' do
              expect(result).to eql(manager)
            end
          end

          context 'when the manager cannot detect its dependency signature' do
            let(:detected) {false}

            it 'is nil' do
              expect(result).to eql(nil)
            end
          end

        end

        describe '#detected?' do
          let(:result) {manager.detected?}

          it 'is false' do
            expect(result).to eql(false)
          end
        end

        describe '#check' do
          let(:result) {manager.check}

          it 'is nil' do
            expect(result).to eql(nil)
          end
        end

        describe '#install' do
          let(:result) {manager.install}

          it 'is nil' do
            expect(result).to eql(nil)
          end
        end

        describe '#uses_sqlite3?' do
          let(:result) {manager.uses_sqlite3?}

          it 'is nil' do
            expect(result).to eql(nil)
          end
        end

        describe '#rails_version' do
          let(:result) {manager.rails_version}

          it 'is nil' do
            expect(result).to eql(nil)
          end
        end

        describe '#show_ey_config_instructions' do
          let(:result) {manager.show_ey_config_instructions}

          it 'is nil' do
            expect(result).to eql(nil)
          end
        end

        describe '#paths' do
          let(:paths) {Object.new}
          let(:result) {manager.instance_eval {paths}}

          before(:each) do
            allow(config).to receive(:paths).and_return(paths)
          end

          it 'is the config paths' do
            expect(result).to eql(paths)
          end
        end

        describe '#on_roles' do
          let(:result) {manager.instance_eval {on_roles}}

          it 'is an array' do
            expect(result).to be_a(Array)
          end

          it 'applies to app masters' do
            expect(result).to include(:app_master)
          end

          it 'applies to app instances' do
            expect(result).to include(:app)
          end

          it 'applies to solo instances' do
            expect(result).to include(:solo)
          end

          it 'applies to util instances' do
            expect(result).to include(:util)
          end

          it 'does not apply to database instances' do
            expect(result).not_to include(:db_master)
            expect(result).not_to include(:db_slave)
          end
        end

      end

    end
  end
end
