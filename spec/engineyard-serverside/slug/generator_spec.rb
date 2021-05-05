require 'spec_helper'

require 'result'
require 'engineyard-serverside/slug/generator'

module EY
  module Serverside
    module Slug

      describe Generator do
        let(:release_name) {'123456789'}
        let(:app_name) {'george'}
        let(:servers) {[]}
        let(:config) {Object.new}
        let(:shell) {Object.new}
        let(:success) {Result::Success.new(nil)}
        let(:failure) {Result::Failure.new(nil)}

        describe '.generate' do
          let(:data) {
            {
              :app_name => app_name,
              :release_name => release_name,
              :config => config,
              :shell => shell,
              :servers => servers,
            }
          }

          let(:ogun) {
            "/engineyard/bin/ogun build #{app_name} --release #{release_name}"
          }

          let(:generate) {described_class.generate(data)}

          before(:each) do
            allow(shell).to receive(:logged_system).and_return(failure)
          end

          it 'is a Result' do
            expect(generate).to be_a(Result::Base)
          end

          context 'when the ogun command fails' do
            before(:each) do
              allow(shell).
                to receive(:logged_system).
                with(ogun).
                and_return(failure)
            end

            it 'is a failure' do
              expect(generate).to be_a(Result::Failure)
            end

            it 'records a build error' do
              expect(generate.error[:error]).to eql('Ogun build failed')
            end
          end

          context 'when the ogun command succeeds' do
            before(:each) do
              allow(shell).
                to receive(:logged_system).
                with(ogun).
                and_return(success)
            end

            it 'is a success' do
              expect(generate).to be_a(Result::Success)
            end

            it 'records that a build was generated' do
              expect(generate.value[:generated]).to eql(true)
            end
          end
        end

      end
    end
  end
end
