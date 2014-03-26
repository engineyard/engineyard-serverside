require 'set'
require 'tempfile'

module EY
  module Serverside
    class Server < Struct.new(:hostname, :roles, :name, :user)
      def self.from_hash(server_hash)
        new(server_hash[:hostname], Set.new(server_hash[:roles].map{|r|r.to_sym}), server_hash[:name], server_hash[:user])
      end

      def authority
        "#{user}@#{hostname}"
      end

      def inspect
        name_s = name && ":#{name}"
        "#{hostname}(#{role}#{name_s})"
      end

      def role
        roles.to_a.first
      end

      def matches_roles?(set)
        (roles & set).any?
      end

      def roles=(roles)
        roles_set = Set.new roles.map{|r| r.to_sym}
        super roles_set
      end

      def local?
        hostname == 'localhost'
      end

      def sync_directory_command(directory)
        return nil if local?
        [
          remote_command("mkdir -p #{directory}"),
          # File mod times aren't important during deploy, and
          # -a (archive mode) sets --times which causes problems.
          # -a is equivalent to -rlptgoD. We remove the -t, and add -q.
          Escape.shell_command(%w[rsync --delete -rlpgoDq -e] + [ssh_command, "#{directory}/", "#{user}@#{hostname}:#{directory}"])
        ].join(' && ')
      end

      def scp_command(local_file, remote_file)
        Escape.shell_command([
          'scp',
          '-i', "#{ENV['HOME']}/.ssh/internal",
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=#{self.class.known_hosts_file.path}",
          "-o", "PasswordAuthentication=no",
          local_file,
          "#{authority}:#{remote_file}",
        ])
      end

      def command_on_server(prefix, cmd, &block)
        command = block ? block.call(self, cmd.dup) : cmd
        command = "#{prefix} #{Escape.shell_command([command])}"
        local? ? command : remote_command(command)
      end

      def run(command)
        yield local? ? command : remote_command(command)
      end

      # Explicitly putting that space in helps us make sure we don't
      # accidentally leave off the space on the end of ssh_command.
      def remote_command(command)
        ssh_command + " " + Escape.shell_command(["#{user}@#{hostname}", command])
      end

      # Make a known hosts tempfile to absorb host fingerprints so we don't show
      #
      #     Warning: Permanently added 'xxx' (RSA) to the list of known hosts.
      #
      # for every ssh command.
      # (even with StrictHostKeyChecking=no, the warning output is annoying)
      def self.known_hosts_file
        @known_hosts_file ||= Tempfile.new('ey-ss-known-hosts')
      end

      def ssh_command
        "ssh -i #{ENV['HOME']}/.ssh/internal -o StrictHostKeyChecking=no -o UserKnownHostsFile=#{self.class.known_hosts_file.path} -o PasswordAuthentication=no -o ServerAliveInterval=60"
      end

    end
  end
end
