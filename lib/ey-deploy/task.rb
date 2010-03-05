module EY
  class Task

    attr_reader :config
    alias :c :config

    def initialize(conf)
      @config = conf
      @roles = :all
    end

    def require_custom_tasks
      deploy_file = ["config/eydeploy.rb", "eydeploy.rb"].detect do |file|
        File.exists?(File.join(c.repository_cache, file))
      end
      require File.join(c.repository_cache, deploy_file) if deploy_file
    end

    def roles(*task_roles)
      raise "Roles must be passed a block" unless block_given?

      begin
        @roles = task_roles
        yield
      ensure
        @roles = :all
      end
    end

    def run(cmd)
      EY::Server.from_roles(@roles).each do |server|
        server.run %|sudo -u #{c.user} sh -c "#{cmd} 2>&1"|
      end
    end

    def sudo(cmd)
      EY::Server.from_roles(@roles).each do |server|
        server.run %|sh -c "#{cmd} 2>&1"|
      end
    end
  end
end
