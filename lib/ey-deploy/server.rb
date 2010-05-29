require 'open-uri'
require 'ey-deploy/verbose_system'

module EY
  class Server < Struct.new(:hostname, :role, :name)
    include VerboseSystem

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

    def self.all
      @servers ||= ([current] << app_slaves << db_master << db_slaves << utils).flatten.compact
    end

    def self.current
      @current ||= new(open("http://169.254.169.254/latest/meta-data/local-hostname").read, EY.node["instance_role"].to_sym)
    end

    def self.app_slaves
      @app_slaves ||= Array(EY.node["members"]).map do |slave|
        new(slave, :app)
      end.reject do |server|
        server.hostname == current.hostname
      end
    end

    def self.db_master
      return @db_master if @db_master
      if EY.node["instance_role"] == "solo"
        @db_master = nil
      else
        @db_master = EY.node["db_host"] && new(EY.node["db_host"], :db_master)
      end
    end

    def self.db_slaves
      EY.node["db_slaves"].map do |slave|
        new(slave, :db_slave)
      end
    end

    def self.utils
      EY.node["utility_instances"].map do |server|
        new(server["hostname"], :util, server["name"])
      end
    end

    def local?
      [:app_master, :solo].include?(role)
    end

    def push_code
      return if local?
      run "mkdir -p #{config.repository_cache}"
      system(%|rsync --delete -aq -e "#{ssh_command}" #{config.repository_cache}/ #{config.user}@#{hostname}:#{config.repository_cache}|)
    end

    def run(command)
      if local?
        system(command)
      else
        system(ssh_command + " " + Escape.shell_command(["#{config.user}@#{hostname}", command]))
      end
    end

    def ssh_command
      "ssh -i /home/#{config.user}/.ssh/internal"
    end
  end
end

