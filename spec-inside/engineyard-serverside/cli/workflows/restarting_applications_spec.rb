require 'spec_helper'
require 'ostruct'

require 'engineyard-serverside/cli/workflows/restarting_applications'

module EY
  module Serverside
    module CLI
      module Workflows
        describe RestartingApplications do
          let(:shell) {Object.new}
          let(:config) {
            OpenStruct.new(:user => 'joeuser', :group => 'joegroup')
          }

          let(:app) {'someapp'}
          let(:instances) {['instance1', 'instance2', 'instance3']}
          let(:deployer) {Object.new}
          let(:app_dir_path_name) {Object.new}
          let(:current_app_dir) {Object.new}
          let(:revision) {Object.new}

          let(:server1) {
            OpenStruct.new(
              :local? => true
            )
          }

          let(:server2) {
            OpenStruct.new(
              :local? => false
            )
          }

          let(:servers) {
            ServerCollection.new([server1, server2], shell)
          }

          let(:pool) {Object.new}

          let(:options) {
            {
              :instances => instances,
              :app => app
            }
          }

          let(:workflow) {described_class.new(options)}

          before(:each) do
            allow(shell).to receive(:fatal)
            allow(shell).to receive(:debug)
            allow(shell).to receive(:logged_system)
            allow(shell).to receive(:command_show)
            allow(shell).to receive(:command_err)

            allow(config).to receive(:verbose)
            allow(config).to receive(:app)

            allow(workflow).to receive(:shell).and_return(shell)
            allow(workflow).to receive(:config).and_return(config)
            allow(workflow).to receive(:servers).and_return(servers)

            allow(Pathname).
              to receive(:new).
              with("/data/#{app}/current").
              and_return(app_dir_path_name)

            allow(app_dir_path_name).
              to receive(:join).
              with('current').
              and_return(current_app_dir)

            allow(current_app_dir).
              to receive(:realpath).
              and_return("/data/#{app}/current")

            allow(current_app_dir).
              to receive(:join).
              with('REVISION').
              and_return(revision)

            allow(revision).
              to receive(:read).
              and_return("somerevision")

            [server1, server2].each do |server|
              allow(server).to receive(:command_on_server)
              allow(server).to receive(:sync_directory_command)
            end

            allow(EY::Serverside::Spawner::Pool).
              to receive(:new).
              and_return(pool)

            allow(pool).to receive(:run).and_return([OpenStruct.new(:success? => true)])
            allow(pool).to receive(:add)

          end

          it 'is a CLI Workflow' do
            expect(workflow).to be_a(EY::Serverside::CLI::Workflows::Base)
          end

          it 'has a task name' do
            expect(workflow.instance_eval {task_name}).
              to eql('restart')
          end

          describe '#perform' do
            let(:perform) {workflow.perform}

            before(:each) do
              allow(workflow).to receive(:propagate_serverside)
              allow(workflow).to receive(:deployer).and_return(deployer)
              allow(deployer).to receive(:restart_with_maintenance_page)
            end

            it 'explicitly sets deploy options for a restart' do
              expect(workflow.options[:release_path]).to be_nil

              perform

              expect(workflow.options[:release_path]).not_to be_nil
            end

            it 'propagates serverside' do
              expect(workflow).to receive(:propagate_serverside)

              perform
            end

            it 'restarts with maintenance enabled' do
              expect(deployer).to receive(:restart_with_maintenance_page)

              perform
            end

          end
        end
      end
    end
  end
end
