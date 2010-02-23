module EY
  class Task
    DEFAULT_CONFIG = {
      "migration_command" => "rake db:schema:load",
      "branch"            => 'master',
      "copy_exclude"      => '.git',
      "strategy"          => "Git",
    }

    attr_reader :configuration

    def initialize(opts={})
      @configuration = opts
    end

    # Delegate to the configuration objects
    def method_missing(meth, *args, &blk)
      if configuration.key?(meth.to_s)
        configuration[meth.to_s]
      else
        super
      end
    end

    def respond_to?(meth)
      if configuration.key?(meth.to_s)
        true
      else
        super
      end
    end

    # Helpers
    def node
      @node ||= JSON.parse(File.read(EY::DNA_FILE))
    end

    def repository_cache
      configuration['repository_cache'] || File.join(deploy_to, "/shared/cached-copy")
    end

    def repo
      configuration['repo'] || node["applications"][app]["repository_name"]
    end

    def deploy_to
      configuration['deploy_to'] || "/data/#{app}"
    end

    def migrate
      !!configuration['migration_command']
    end
    alias :migrate? :migrate
  end
end
