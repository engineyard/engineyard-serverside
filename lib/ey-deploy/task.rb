module EY
  class Task

    attr_reader :config
    alias :c :config

    def initialize(conf)
      @config = conf
    end

    def require_custom_tasks
      deploy_file = ["config/eydeploy.rb", "eydeploy.rb"].detect do |file|
        File.exists?(File.join(c.repository_cache, file))
      end
      require File.join(c.repository_cache, deploy_file) if deploy_file
    end

    def run(cmd)
      res = `sudo -u #{c.user} sh -c "#{cmd} 2>&1"`
      unless $? == 0
        puts res
        exit 1
      end
      res
    end

    def sudo(cmd)
      res = `sh -c "#{cmd} 2>&1"`
      unless $? == 0
        puts res
        exit 1
      end
      res
    end
  end
end
