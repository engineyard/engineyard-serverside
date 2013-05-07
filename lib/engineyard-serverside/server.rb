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
        roles.first
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
          Escape.shell_command(%w[rsync --delete -aq -e] + [ssh_command, "#{directory}/", "#{user}@#{hostname}:#{directory}"])
        ].join(' && ')
      end

      def command_on_server(prefix, cmd, &block)
        command = block ? block.call(self, cmd.dup) : cmd
        command = "#{prefix} <<CMD\n#{cmd}\nCMD"
        local? ? command : remote_command(command)
      end

      def run(command)
        yield local? ? command : remote_command(command)
      end

      def remote_command(command)
        ssh_command + Escape.shell_command(["#{user}@#{hostname}", command])
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
        "ssh -i #{ENV['HOME']}/.ssh/internal -o StrictHostKeyChecking=no -o UserKnownHostsFile=#{self.class.known_hosts_file.path} -o PasswordAuthentication=no "
      end

    end
  end
end
