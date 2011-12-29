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
          logged_system(ssh_command + Escape.shell_command(["#{user}@#{hostname}", command]))
        end
      end

      def copy(local_file, remote_file)
        logged_system(scp_command + Escape.shell_command([local_file, "#{user}@#{hostname}:#{remote_file}"]))
      end

      def ssh_command
        "ssh #{ssh_options} "
      end

      def scp_command
        "scp #{ssh_options} "
      end

      def ssh_options
        "-i #{ENV['HOME']}/.ssh/internal -o StrictHostKeyChecking=no -o PasswordAuthentication=no"
      end

      def gem?(name, version)
        run("#{gem_command} list -i #{name} -v '#{version}'")
      end

      def install_gem(path)
        # resin + ruby 1.8.6 need sudo privileges to install gems
        run("sudo #{gem_command} install -q --no-ri --no-rdoc #{path}")
      end

      def gem_command
        File.expand_path('gem', Gem.default_bindir)
      end

    end
  end
end
