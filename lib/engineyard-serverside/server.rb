require 'set'
require 'tempfile'

module EY
  module Serverside
    class Server
      attr_reader :hostname, :roles, :name, :user

      def initialize(hostname, roles, name, user)
        @hostname = hostname
        @name = name
        @user = user

        @roles = Set.new(roles.map {|role| role.to_sym})
      end

      # Initialize a new Server from a hash of server elements
      def self.from_hash(server_hash)
        new(
          server_hash[:hostname],
          server_hash[:roles],
          server_hash[:name],
          server_hash[:user]
        )
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

      def matches_roles?(set)
        (roles & Set.new(set.map {|role| role.to_sym})).any?
      end

      def command_on_server(prefix, cmd, &block)
        command = block ? block.call(self, cmd.dup) : cmd
        command = "#{prefix} #{Escape.shell_command([command])}"
        local? ? command : remote_command(command)
      end

      def inspect
        name_s = name && ":#{name}"
        "#{hostname}(#{role}#{name_s})"
      end

      def local?
        hostname == 'localhost'
      end


      private

      def authority
        "#{user}@#{hostname}"
      end

      def role
        roles.to_a.first
      end

      def sync_directory_command(directory, ignore_existing = false)
        return nil if local?
        ignore_flag = ignore_existing ? ["--ignore-existing"] : []
        [
          remote_command("mkdir -p #{directory}"),
          # File mod times aren't important during deploy, and
          # -a (archive mode) sets --times which causes problems.
          # -a is equivalent to -rlptgoD. We remove the -t, and add -q.
          Escape.shell_command(%w[rsync --delete -rlpgoDq] + ignore_flag + ["-e", ssh_command, "#{directory}/", "#{user}@#{hostname}:#{directory}"])
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

      # Explicitly putting that space in helps us make sure we don't
      # accidentally leave off the space on the end of ssh_command.
      def remote_command(command)
        ssh_command +
          " " +
          Escape.shell_command(["#{user}@#{hostname}", command])
      end

      def ssh_command
        "ssh -i #{ENV['HOME']}/.ssh/internal -o StrictHostKeyChecking=no -o UserKnownHostsFile=#{self.class.known_hosts_file.path} -o PasswordAuthentication=no -o ServerAliveInterval=60"
      end

    end
  end
end
