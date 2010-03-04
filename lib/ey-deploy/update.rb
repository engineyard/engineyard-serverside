module EY
  class UpdateBase < Task

    # default task
    def update
      update_repository_cache
      require_custom_tasks
      push_code
      deploy
    end

    # task
    def push_code
      EY::Server.all.each do |server|
        server.push_code
      end
    end

    # task
    def deploy
      EY::Server.all.each do |server|
        puts "~ Deploying with #{deploy_command(server)}"
        server.run(deploy_command(server))
      end
    end

    def deploy_command(server)
      "eysd deploy #{server.default_task} -a #{c.app} #{migrate_option}"
    end

    def migrate_option
      if c.migrate?
        %|--migrate \\"#{c.migration_command}\\"|
      else
        "--no-migrate"
      end
    end

  end

  class Update < UpdateBase
    def self.new(opts={})
      # include the correct fetch strategy
      include EY::Strategies.const_get(opts.strategy)::Helpers
      super
    end

    def self.run(opts={})
      conf = EY::Deploy::Configuration.new(opts)
      EY::Server.repository_cache = conf.repository_cache
      update = new(conf).send(opts["default_task"])
    end
  end
end
