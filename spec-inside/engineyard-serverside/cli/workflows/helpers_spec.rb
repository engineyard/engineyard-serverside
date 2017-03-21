require 'spec_helper'

require 'engineyard-serverside/cli/workflows/helpers'

class Helpful
  include EY::Serverside::CLI::Workflows::Helpers
end

module EY
  module Serverside
    module CLI
      module Workflows
        describe Helpers do
          let(:config) {Object.new}
          let(:shell) {Object.new}
          let(:servers) {Object.new}
          let(:workflow) {Helpful.new}

          before(:each) do
            allow(shell).to receive(:fatal)
            allow(shell).to receive(:debug)

            allow(config).to receive(:verbose)
            allow(config).to receive(:app)

            allow(workflow).to receive(:shell).and_return(shell)
            allow(workflow).to receive(:config).and_return(config)
            allow(workflow).to receive(:servers).and_return(servers)
          end

          describe '#deployer' do
            let(:result) {Object.new}
            let(:deployer) {workflow.deployer}

            it 'is a Deploy for our workflow' do
              expect(EY::Serverside::Deploy).
                to receive(:new).
                with(servers, config, shell).
                and_return(result)

              expect(deployer).to eql(result)
            end
          end

          describe '#maintenance' do
            let(:result) {Object.new}
            let(:maintenance) {workflow.maintenance}

            it 'is a Maintenance for our workflow' do
              expect(EY::Serverside::Maintenance).
                to receive(:new).
                with(servers, config, shell).
                and_return(result)

              expect(maintenance).to eql(result)
            end
          end


        end
      end
    end
  end
end
