require 'spec_helper'

require 'engineyard-serverside/server'
require 'engineyard-serverside/servers'

module EY
  module Serverside
    describe Servers do
      let(:remote_server) {
        Server.new('remote-host', Set.new([:util, :app]), nil, nil)
      }

      let(:local_server) {
        Server.new('localhost', Set.new([:app_master, :app]), nil, nil)
      }

      let(:servers) {[remote_server, local_server]}
      let(:shell) {Object.new}
      let(:server_collection) {described_class.new(servers, shell)}

      it 'is Enumerable' do
        expect(described_class).to include(Enumerable)
      end

      describe '.from_hashes' do
        let(:hashes) {
          [
            {
              :hostname => "server1",
              :roles => [:app],
              :name => "jim",
              :user => "deploy"
            },
            {
              :hostname => "server2",
              :roles => [:app],
              :name => "bob",
              :user => "deploy"
            }
          ]
        }

        let(:from_hashes) {described_class.from_hashes(hashes, shell)}

        it 'is a ServerCollection' do
          expect(from_hashes).to be_a(described_class)
        end

        it 'contains a Server for each hash passed in' do
          expect(from_hashes.size).to eql(hashes.length)
        end
      end

      describe '#localhost' do
        let(:localhost) {server_collection.localhost}

        context 'when there are no local servers in the collection' do
          let(:servers) {[remote_server]}
          it 'is nil' do
            expect(localhost).to be_nil
          end
        end

        context 'when there is a local server in the collection' do
          let(:servers) {[remote_server, local_server]}

          it 'is the local server' do
            expect(localhost).to eql(local_server)
          end
        end
      end

      describe '#remote' do
        let(:servers) {[local_server, remote_server]}
        let(:remote) {server_collection.remote}

        it 'is a ServerCollection' do
          expect(remote).to be_a(described_class)
        end

        it 'includes remote servers' do
          expect(remote).to include(remote_server)
        end

        it 'excludes local servers' do
          expect(remote).not_to include(local_server)
        end

        context 'when there are no servers in the collection' do
          let(:servers) {[]}

          it 'is empty' do
            expect(remote).to be_empty
          end
        end
      end

      describe '#in_groups' do
        let(:server1) {EY::Serverside::Server.new('server1', nil, nil, nil)}
        let(:server2) {EY::Serverside::Server.new('server2', nil, nil, nil)}
        let(:server3) {EY::Serverside::Server.new('server1', nil, nil, nil)}
        let(:servers) {[server1, server2, server3]}

        let(:group_size) {2}
        let(:groups) {[]}

        before(:each) do
          server_collection.in_groups(group_size) do |group|
            groups.push(group)
          end
        end

        it 'splits the collection into groups of the appropriate size' do
          expect(groups.first.size).to eql(group_size)
          expect(groups.last.size).to eql(1)
        end

        it 'splits the collection into multiple collections' do
          groups.each do |group|
            expect(group).to be_a(described_class)
          end
        end

        it 'includes all servers in the collection' do
          servers.each do |server|
            expect(groups.map(&:to_a).flatten).to include(server)
          end
        end
      end

      describe '#roles' do

        it 'is a server collection' do
          expect(server_collection.roles).to be_a(described_class)
        end


        context 'with no roles provided' do
          let(:roles) {server_collection.roles}

          it 'contains all of the servers in the collection' do
            expect(roles.to_a).to eql(servers)
          end
        end

        context 'when the :all role is requested' do
          let(:roles) {server_collection.roles(:db_master, :all)}

          it 'contains all of the servers in the collection' do
            expect(roles.to_a).to eql(servers)
          end
        end

        context 'when none of the servers match the given roles' do
          let(:roles) {server_collection.roles(:db_master, :db_slave, :solo)}

          it 'is an empty collection' do
            expect(roles).to be_empty
          end
        end

        context 'when an applicable role is given' do
          let(:roles) {server_collection.roles(:util)}

          it 'contains servers with that role' do
            expect(roles.to_a).to include(remote_server)
          end

          it 'omits servers without that role' do
            expect(roles.to_a).not_to include(local_server)
          end
        end

        context 'with a block' do
          it 'yields the resulting collection to the block' do
            expected_roles = server_collection.roles(:util).to_a
            result = nil

            server_collection.roles(:util) do |collection|
              result = collection.to_a
            end

            expect(expected_roles).to eql(result)
          end
        end
      end

      describe '#run_on_each'

      describe '#run_on_each!'

      describe '#run'

      describe '#sudo_on_each'

      describe '#sudo_on_each!'

      describe '#sudo'

      describe '#run_for_each'

      describe '#run_for_each!'

      describe '#select' do
        let(:selected) {
          server_collection.select {|server| server.hostname == 'localhost'}
        }

        it 'is a server collection' do
          expect(selected).to be_a(described_class)
        end

        it 'contains each server for which the block is truthy' do
          expect(selected.to_a).to include(local_server)
        end

        it 'omits servers for which the block is not truthy' do
          expect(selected.to_a).not_to include(remote_server)
        end
      end

      describe '#reject' do
        let(:rejected) {
          server_collection.reject {|server| server.hostname == 'localhost'}
        }

        it 'is a server collection' do
          expect(rejected).to be_a(described_class)
        end

        it 'contains each server for which the block is not truthy' do
          expect(rejected).to include(remote_server)
        end

        it 'omits servers for which the block is truthy' do
          expect(rejected).not_to include(local_server)
        end
      end
      
      describe '#to_a' do
        let(:to_a) {server_collection.to_a}

        it 'is an Array' do
          expect(to_a).to be_a(Array)
        end

        it 'contains each server in the collection' do
          servers.each do |server|
            expect(to_a).to include(server)
          end
        end
      end



    end
  end
end
