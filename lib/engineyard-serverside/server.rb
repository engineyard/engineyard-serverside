require 'open-uri'
require 'engineyard-serverside/logged_output'

module EY
  module Serverside
    class Server < Struct.new(:hostname, :roles, :name, :user)
      include LoggedOutput

      class DuplicateHostname < StandardError
        def initialize(hostname)
          super "There is already an EY::Serverside::Server with hostname '#{hostname}'"
        end
      end

      def initialize(*fields)
        super
        self.roles = self.roles.map { |r| r.to_sym } if self.roles
      end

      attr_writer :default_task

      def self.from_roles(*want_roles)
        want_roles = want_roles.flatten.compact.map{|r| r.to_sym}
        return all if !want_roles || want_roles.include?(:all) || want_roles.empty?

        all.select do |s|
          !(s.roles & want_roles).empty?
        end
      end

      def role
        roles.first
      end

      def self.load_all_from_array(server_hashes)
        server_hashes.each do |instance_hash|
          add(instance_hash)
        end
      end

      def self.all
        @all
      end

      def self.by_hostname(hostname)
        all.find{|s| s.hostname == hostname}
      end

      def self.add(server_hash)
        hostname = server_hash[:hostname]
        if by_hostname(hostname)
          raise DuplicateHostname.new(hostname)
        end
        server = new(hostname, server_hash[:roles], server_hash[:name], server_hash[:user])
        @all << server
        server
      end

      def self.current
        all.find {|s| s.local? }
      end

      def self.reset
        @all = []
      end
      reset

      def roles=(roles)
        super(roles.map{|r| r.to_sym})
      end

      def local?
        hostname == 'localhost'
      end

      def sync_directory(directory)
        return if local?
        run "mkdir -p #{directory}"
        logged_system(%|rsync --delete -aq -e "#{ssh_command}" #{directory}/ #{user}@#{hostname}:#{directory}|)
      end

      def run(command)
        if local?
          logged_system(command)
        else
          logged_system(ssh_command + " " + Escape.shell_command(["#{user}@#{hostname}", command]))
        end
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
