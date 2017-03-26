require 'spec_helper'

require 'engineyard-serverside/propagator'

module EY
  module Serverside
    describe Propagator do
      let(:spawner) {Object.new}
      let(:shell) {Object.new}
      let(:server1) {EY::Serverside::Server.new('server1', nil, nil, nil)}
      let(:server2) {EY::Serverside::Server.new('server2', nil, nil, nil)}
      let(:servers) {EY::Serverside::Servers.new([server1, server2], shell)}

      let(:propagator) {described_class.new(servers, shell)}

      before(:each) do
        allow(shell).to receive(:status)
        allow(EY::Serverside::Spawner).to receive(:new).and_return(spawner)
        allow(spawner).to receive(:add)
        allow(spawner).to receive(:run).and_return([])
      end

      describe '#propagate' do
        let(:propagate) {propagator.propagate}

        it 'announces the propagation on the shell' do
          expect(shell).
            to receive(:status).
            with("Verifying and propagating #{EY::Serverside::About.name_with_version} to all servers.")

          propagate
        end

        it 'runs the propagation command on each server' do
          servers.each do |server|
            command = propagator.instance_eval {
              propagation_command_for(server)
            }

            expect(spawner).
              to receive(:add).
              with(
                command,
                shell,
                server
              )
          end

          expect(spawner).to receive(:run).and_return([])

          propagate
        end
      end
    end
  end
end
