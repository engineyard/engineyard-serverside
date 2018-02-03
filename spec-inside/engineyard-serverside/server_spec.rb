require 'spec_helper'

require 'engineyard-serverside/server'

module EY
  module Serverside
    describe Server do
      let(:hostname) {'localhost'}
      let(:roles) {[:app_master, :util]}
      let(:name) {'george'}
      let(:user) {'randomhacker'}
      let(:server) {described_class.new(hostname, roles, name, user)}

      describe '.from_hash' do
        let(:from_hash) {
          described_class.from_hash(
            {
              :hostname => hostname,
              :roles => roles,
              :name => name,
              :user => user,
            }
          )
        }

        it 'is a Server' do
          expect(from_hash).to be_a(described_class)
        end
      end

      describe '#role' do
        let(:role) {server.role}

        it 'is the first role in the role list' do
          expect(role).to eql(roles.first)
        end
      end

      describe '#authority' do
        let(:authority) {server.authority}

        it 'is an SSH signature for the server' do
          expect(authority).to eql("#{user}@#{hostname}")
        end
      end

      describe '#inspect' do
        let(:sinspect) {server.inspect}

        it 'is a string' do
          expect(sinspect).to be_a(String)
        end

        it 'includes the server hostname and role' do
          expect(sinspect).to include(hostname)
          expect(sinspect).to include(server.role.to_s)
        end

        context 'when the server has a name' do
          it 'contains the name' do
            expect(sinspect).to include(":#{name})")
          end
        end

        context 'when the server has no name' do
          let(:name) {nil}

          it 'omits the name marker' do
            expect(sinspect).not_to include("#{server.role}:")
          end
        end
      end

      describe '#local?' do
        let(:local) {server.local?}

        context 'for a localhost server' do
          it 'is true' do
            expect(local).to eql(true)
          end
        end

        context 'for a non-localhost server' do
          let(:hostname) {'some-remote-host'}

          it 'is false' do
            expect(local).to eql(false)
          end
        end
      end

      describe '#matches_roles?' do
        let(:questionable) {[]}
        let(:matches_roles) {server.matches_roles?(questionable)}

        context 'when the provided roles is an empty list' do
          it 'is false' do
            expect(matches_roles).to eql(false)
          end
        end

        context 'when the provided roles contains none of the server roles' do
          let(:questionable) {[:romeo, :tybalt, :mercutio]}

          it 'is false' do
            expect(matches_roles).to eql(false)
          end
        end

        context 'when the provided roles contains at least one server role' do
          let(:questionable) {[:romeo, :util, :tybalt]}

          it 'is true' do
            expect(matches_roles).to eql(true)
          end
        end

      end

      describe '#command_on_server' do
        let(:prefix) {'before'}
        let(:command) {"true"}

        context 'when no block is passed' do
          let(:command_on_server) {server.command_on_server(prefix, command)}

          it 'is a string' do
            expect(command_on_server).to be_a(String)
          end

          context 'on a local server' do
            it 'is the prefixed escaped command' do
              expect(command_on_server).
                to eql("#{prefix} #{Escape.shell_command([command])}")
            end
          end

          context 'on a remote server' do
            let(:hostname) {'some-remote-host'}
            let(:ssh_command) {server.instance_eval {ssh_command}}

            it 'is a remote prefixed escaped command' do
              escaped = Escape.shell_command([command])
              prefixed = "#{prefix} #{escaped}"

              expect(command_on_server).
                to eql("#{ssh_command} #{Escape.shell_command([server.authority, prefixed])}")
            end
          end
        end

        context 'when a block is passed' do
          let(:block_result) {"#{command} on #{server}"}

          let(:command_on_server) {
            server.command_on_server(prefix, command) {|server, command|
              block_result
            }
          }

          it 'is a string' do
            expect(command_on_server).to be_a(String)
          end

          context 'on a local server' do
            it 'is the prefixed escaped block result' do
              expect(command_on_server).
                to eql("#{prefix} #{Escape.shell_command([block_result])}")
            end
          end

          context 'on a remote server' do
            let(:hostname) {'some-remote-host'}
            let(:ssh_command) {server.instance_eval {ssh_command}}

            it 'is a remote prefixed escaped block result' do
              escaped = Escape.shell_command([block_result])
              prefixed = "#{prefix} #{escaped}"

              expect(command_on_server).
                to eql("#{ssh_command} #{Escape.shell_command([server.authority, prefixed])}")
            end
          end
        end
      end

      describe '#sync_directory_command' do
        let(:directory) {"/some/directory"}
        let(:ssh_command) {server.ssh_command}
        let(:sync_directory_command) {server.sync_directory_command(directory)}

        context 'for a local server' do
          it 'is nil' do
            expect(sync_directory_command).to be_nil
          end
        end

        context 'for a remote server' do
          let(:ignore_flag) {[]}
          let(:hostname) {'some-remote-host'}
          let(:parts) {sync_directory_command.split(" && ")}


          it 'is a string' do
            expect(sync_directory_command).to be_a(String)
          end

          it 'includes the creation of the remote directory' do
            mkdir = server.remote_command("mkdir -p /some/directory")
            expect(parts.first).to eql(mkdir)
          end

          it 'includes the rsync of the directory to the remote' do
            rsync_command = %w[rsync --delete -rlpgoDq] +
              [
                "-e",
                ssh_command,
                "#{directory}/",
                "#{server.authority}:#{directory}"
              ]

            rsync = Escape.shell_command(rsync_command)

            expect(parts.last).to eql(rsync)
          end

          context 'when ignore_existing is' do

            context 'not provided' do
              it 'omits the --ignore-existing flag' do
                expect(parts.last).not_to include('--ignore-existing')
              end
            end

            context 'not truthy' do
              let(:ignore_existing) {false}
              let(:sync_directory_command) {server.sync_directory_command(directory, ignore_existing)}

              it 'omits the --ignore-existing flag' do
                expect(parts.last).not_to include('--ignore-existing')
              end
            end


            context 'truthy' do
              let(:ignore_existing) {true}
              let(:sync_directory_command) {server.sync_directory_command(directory, ignore_existing)}

              it 'includes the --ignore-existing flag' do
                expect(parts.last).to include('--ignore-existing')
              end
            end

          end

        end
      end

      describe '#scp_command' do
        let(:local_file) {'/local/file'}
        let(:remote_file) {'/remote/file'}

        let(:scp_command) {server.scp_command(local_file, remote_file)}
        let(:command_items) {scp_command.split(/\s+/)}

        it 'is a string' do
          expect(scp_command).to be_a(String)
        end

        it 'is an scp command string' do
          expect(command_items.first).to eql('scp')
        end

        it 'uses the internal SSH identity' do
          expect(scp_command).to include("-i #{ENV['HOME']}/.ssh/internal")
        end

        it 'does not use strict host key checking' do
          expect(scp_command).to include('-o StrictHostKeyChecking=no')
        end

        it 'uses the class known hosts file' do
          expect(scp_command).
            to include(
              "-o UserKnownHostsFile=#{described_class.known_hosts_file.path}"
            )
        end

        it 'does not use password authentication' do
          expect(scp_command).to include('-o PasswordAuthentication=no')
        end

        it 'specifies the local file as the origin' do
          expect(command_items[-2]).to eql(local_file)
        end

        it 'specifies the remote file (with authority) as the target' do
          expect(command_items.last).to eql("#{server.authority}:#{remote_file}")
        end
      end

      describe '#run'

      describe '#remote_command'

      describe '#ssh_command' do
        let(:ssh_command) {server.ssh_command}
        let(:command_items) {ssh_command.split(/\s+/)}

        it 'is a SSH command string' do
          expect(ssh_command).to be_a(String)
          expect(command_items.first).to eql("ssh")
        end

        it 'uses the internal SSH identity' do
          expect(ssh_command).to include("-i #{ENV['HOME']}/.ssh/internal")
        end

        it 'does not use strict host key checking' do
          expect(ssh_command).to include('-o StrictHostKeyChecking=no')
        end

        it 'uses the class known hosts file' do
          expect(ssh_command).
            to include(
              "-o UserKnownHostsFile=#{described_class.known_hosts_file.path}"
            )
        end

        it 'does not use password authentication' do
          expect(ssh_command).to include('-o PasswordAuthentication=no')
        end

        it 'has a one-minute keepalive interval' do
          expect(ssh_command).to include('-o ServerAliveInterval=60')
        end

      end




    end
  end
end
