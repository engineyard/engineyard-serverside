require 'spec_helper'

require 'engineyard-serverside/server'

module EY
  module Serverside

    describe Server do
      let(:hostname) {'nosuch.server.com'}
      let(:roles) {[:romeo, :mercutio, :tybalt]}
      let(:name) {'superserverx5000'}
      let(:user) {'joe'}
      let(:server_hash) {{
        hostname: hostname,
        roles: roles,
        name: name,
        user: user
      }}

      let(:server) {described_class.from_hash(server_hash)}

      describe '.from_hash' do
        let(:role_set) {Object.new}
        let(:expected) {Object.new}

        let(:result) {described_class.from_hash(server_hash)}

        before(:each) do
          # Stub out the parts of the Set API that we need to be able to express
          # its use.
          allow(Set).to receive(:new).with(roles).and_return(role_set)

          # This is a little dirty, but not incredibly. Server is a Struct with
          # specific attributes. As such, it doesn't have an initializer of its
          # own, and our seam is between Server and Struct, so we can stub out
          # instantiation and check to ensure that it's given the proper values.
          allow(described_class).to receive(:new).and_return(expected)
        end

        it 'instantiates a new Server from a server hash' do
          expect(described_class).
            to receive(:new).
            with(hostname, role_set, name, user)

          result
        end

        it 'is the newly instantiated Server instance' do
          expect(result).to eql(expected)
        end
      end

      describe '.known_hosts_file' do
        let(:tmp) {Object.new}
        let(:result) {described_class.known_hosts_file}

        before(:each) do
          # Of all the design decisions that could have been made here, this
          # class method is stateful, so we have to blow away that state to
          # gurantee the idempotence of the examples here.
          described_class.class_eval do
            @known_hosts_file = nil
          end

          # Stub out the pieces of the Tempfile interface that we use so as to
          # cut down on test artifacts.
          allow(Tempfile).
            to receive(:new).
            with('ey-ss-known-hosts').
            and_return(tmp)
        end

        context 'on initial use' do
          it 'generates a temp file' do
            expect(Tempfile).
              to receive(:new).
              with('ey-ss-known-hosts').
              and_return(tmp)

            result
          end

          it 'returns the generated temp file' do
            expect(result).to eql(tmp)
          end
        end

        context 'on subsequent uses' do
          let(:tmp) {'an established temp file'}

          before(:each) do
            described_class.class_eval do
              @known_hosts_file = tmp
            end

            it 'reuses its existing temp file' do
              expect(Tempfile).not_to receive(:new)

              expect(result).to eql(tmp)
            end
          end
        end
      end

      describe '#authority' do
        let(:result) {server.authority}

        it 'is the SSH signature for the server' do
          expect(result).to eql(user + '@' + hostname)
        end
      end

      describe '#inspect' do
        let(:result) {server.inspect}

        it 'begins with the hostname and role' do
          expect(result).to match(%r{^#{hostname}\(#{server.role}})
        end

        context 'when the server has a name' do
          let(:name) {'wiggly'}

          it 'includes the server name' do
            expect(result).to match(%r{#{name}\)$})
          end
        end

        context 'when the server has no name' do
          before(:each) do
            server_hash.delete(:name)
          end

          it 'does not include a server name' do
            expect(result).to match(%r{#{server.role}\)$})
          end
        end
      end

      describe '#role' do
        let(:result) {server.role}

        it 'is the first role in the role list' do
          expect(result).to eql(:romeo)
        end
      end

      describe '#matches_roles?' do
        let(:candidates) {[]}
        let(:result) {server.matches_roles?(candidates)}

        context 'when the server has all of the candidate roles' do
          let(:candidates) {[:tybalt, :romeo, :mercutio]}

          it 'is true' do
            expect(result).to eql(true)
          end
        end

        context 'when the server has some of the candidate roles' do
          let(:candidates) {[:romeo, :tybalt]}

          it 'is true' do
            expect(result).to eql(true)
          end
        end

        context 'when the server has none of the candidate roles' do
          let(:candidates) {[:benvolio, :gildenstern]}

          it 'is false' do
            expect(result).to eql(false)
          end
        end

        context 'when the candidates list is empty' do
          let(:candidates) {[]}

          it 'is false' do
            expect(result).to eql(false)
          end
        end
      end

      describe '#roles=' do
        let(:candidates) {[:benvolio, :gildenstern]}
        let(:result) {server.roles = candidates}

        it 'removes the original roles' do
          result

          roles.each do |role|
            expect(server.matches_roles?([role])).to eql(false)
          end
        end

        it 'adds the candidate roles' do
          result

          candidates.each do |role|
            expect(server.matches_roles?([role])).to eql(true)
          end
        end
      end

      describe '#local?' do
        let(:result) {server.local?}

        context 'when the hostname is localhost' do
          let(:hostname) {'localhost'}

          it 'is true' do
            expect(result).to eql(true)
          end
        end

        context 'when the hostname is not localhost' do
          let(:hostname) {'a.b.c.d'}

          it 'is false' do
            expect(result).to eql(false)
          end
        end
      end

      describe '#sync_directory_command' do
        let(:directory) {'/path/to/something/interesting'}
        let(:result) {server.sync_directory_command(directory)}

        context 'when the server is local' do
          let(:hostname) {'localhost'}

          it 'is nil' do
            expect(result).to eql(nil)
          end
        end

        context 'when the server is not local' do
          let(:ssh_command) {'dummy_ssh_command'}
          let(:remote_mkdir) {'remote_mkdir'}
          let(:rsync_command) {'rsync_command'}
          let(:hostname) {'donkey.kong'}

          before(:each) do
            allow(server).to receive(:ssh_command).and_return(ssh_command)
            allow(server).to receive(:remote_command).and_return(remote_mkdir)

            allow(Escape).to receive(:shell_command).and_return(rsync_command)
          end

          it 'generates a command to create the full path to the directory remotely' do
            expect(server).to receive(:remote_command).with("mkdir -p #{directory}")

            result
          end

          it 'generates a command to sync the directory to the remote server' do
            expect(Escape).
              to receive(:shell_command).
              with([
                'rsync',
                '--delete',
                '-rlpgoDq',
                '-e',
                ssh_command,
                "#{directory}/",
                "#{user}@#{hostname}:#{directory}"
              ])

            result
          end

          context 'when existing files are to be ignored' do
            let(:result) {server.sync_directory_command(directory, true)}

            it 'adds the ignore existing flag to the rsync command' do
              expect(Escape).
                to receive(:shell_command).
                with([
                  'rsync',
                  '--delete',
                  '-rlpgoDq',
                  '--ignore-existing',
                  '-e',
                  ssh_command,
                  "#{directory}/",
                  "#{user}@#{hostname}:#{directory}"
                ])

              result
            end
          end

          it 'is the remote mkdir and the rsync separated by a shell AND operation' do
            expect(result).to eql("#{remote_mkdir} && #{rsync_command}")
          end
        end
      end

      describe '#scp_command' do
      end

      describe '#command_on_server' do
      end

      describe '#run' do
        let(:command) {'echo'}

        context 'when the server is local' do
          let(:hostname) {'localhost'}

          it 'yields the command unalertered to the given block' do
            server.run(command) do |cmd|
              expect(cmd).to eql(command)
            end
          end
        end

        context 'when the server is not local' do
          let(:hostname) {'pac.man'}

          before(:each) do
            allow(server).to receive(:remote_command) {'totally remote my dude'}
          end

          it 'yields the remote version of the command to the given block' do
            server.run(command) do |cmd|
              expect(cmd).to eql(server.remote_command(command))
            end
          end
        end
      end

      describe '#remote_command' do
        let(:command) {'touch toes'}
        let(:result) {server.remote_command(command)}

        before(:each) do
          allow(server).to receive(:ssh_command).and_return('default ssh command')
        end

        it 'is an SSH command that would run the escaped command on the remote server' do
          expect(result).to eql("#{server.ssh_command} #{user}@#{hostname} '#{command}'")
        end
      end

      describe '#ssh_command' do
        let(:result) {server.ssh_command}
        let(:known_hosts_file) {Object.new}

        before(:each) do
          allow(described_class).
            to receive(:known_hosts_file).
            and_return(known_hosts_file)

          allow(known_hosts_file).
            to receive(:path).
            and_return('less_followed')
        end

        it 'is an ssh invocation' do
          expect(result).to match(%r{^ssh })
        end

        it 'uses the internal ssh key' do
          expect(result).to match(%r{\s-i #{ENV['HOME']}\/\.ssh\/internal\s+})
        end

        it 'disables strict host key checking' do
          expect(result).to match(%r{\s+-o StrictHostKeyChecking=no\s+})
        end

        it 'disables password authentication' do
          expect(result).to match(%r{\s+-o PasswordAuthentication=no\s+})
        end

        it 'sets the keepalive to one minute' do
          expect(result).to match(%r{\s+-o ServerAliveInterval=60})
        end

        it 'specifies a known hosts file' do
          expect(result).
            to match(
              %r{\s+-o UserKnownHostsFile=#{described_class.known_hosts_file.path}}
            )
        end
      end
    end

  end
end
