require 'open-uri'
require 'engineyard-serverside/logged_output'

module EY
  class Server < Struct.new(:hostname, :roles, :name)
    include LoggedOutput

    class DuplicateHostname < StandardError
      def initialize(hostname)
        super "There is already an EY::Server with hostname '#{hostname}'"
      end
    end

    def initialize(*fields)
      super
      self.roles = self.roles.map { |r| r.to_sym } if self.roles
    end

    def self.config=(config)
      @@config = config
    end

    def config
      @@config
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

    def self.from_hash(h)
      new(h[:hostname], h[:roles], h[:name])
    end

    def self.all
      @all
    end

    def self.by_hostname(hostname)
      all.find{|s| s.hostname == hostname}
    end

    def self.add(server_hash)
      if by_hostname(server_hash[:hostname])
        raise DuplicateHostname.new(server_hash[:hostname])
      end
      new_guy = from_hash(server_hash)
      @all << new_guy
      new_guy
    end

    def self.current
      all.find {|s| s.local? }
    end

    def self.reset
      @all = [new('localhost', [], nil)]
    end
    reset

    def roles=(roles)
      super(roles.map{|r| r.to_sym})
    end

    def local?
      hostname == 'localhost'
    end

    def push_code
      return if local?
      run "mkdir -p #{config.repository_cache}"
      logged_system(%|rsync --delete -aq -e "#{ssh_command}" #{config.repository_cache}/ #{config.user}@#{hostname}:#{config.repository_cache}|)
    end

    def run(command)
      if local?
        logged_system(command)
      else
        logged_system(ssh_command + " " + Escape.shell_command(["#{config.user}@#{hostname}", command]))
      end
    end

    def ssh_command
      "ssh -i #{ENV['HOME']}/.ssh/internal -o StrictHostKeyChecking=no -o PasswordAuthentication=no"
    end
  end
end
