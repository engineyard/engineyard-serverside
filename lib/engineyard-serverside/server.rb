require 'open-uri'

module EY
  module Serverside
    class Server < Struct.new(:hostname, :roles, :name, :user)
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
        yield remote_command("mkdir -p #{directory}")
        yield Escap.shell_command(%w[rsync --delete -aq -e] + [ssh_command, "#{directory}/", "#{user}@#{hostname}:#{directory}"])
      end

      def run(command)
        yield local? ? command : remote_command(command)
      end

      def remote_command(command)
        ssh_command + Escape.shell_command(["#{user}@#{hostname}", command])
      end

      def ssh_command
        "ssh -i #{ENV['HOME']}/.ssh/internal -o StrictHostKeyChecking=no -o PasswordAuthentication=no "
      end

    end
  end
end
