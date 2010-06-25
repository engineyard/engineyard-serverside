require 'open-uri'
require 'ey-deploy/logged_output'

module EY
  class Server < Struct.new(:hostname, :role, :name)
    include LoggedOutput

    def initialize(*fields)
      super
      self.role = self.role.to_sym
    end

    def self.config=(config)
      @@config = config
    end

    def config
      @@config
    end

    attr_writer :default_task

    def self.from_roles(*roles)
      roles = roles.flatten.compact
      return all if !roles || roles.include?(:all) || roles.empty?

      all.select do |s|
        roles.include?(s.role) || roles.include?(s.name)
      end
    end

    def self.from_hash(h)
      new(h[:hostname], h[:role], h[:name])
    end

    def self.all
      @all
    end

    def self.all=(server_hashes)
      @all = server_hashes.map { |s| from_hash(s) }
    end

    def self.current
      all.find {|s| s.local? }
    end

    def local?
      [:app_master, :solo].include?(role)
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
      "ssh -i /home/#{config.user}/.ssh/internal -o StrictHostKeyChecking=no -o PasswordAuthentication=no"
    end
  end
end

