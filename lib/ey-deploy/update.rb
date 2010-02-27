module EY
  class Update < Task
    def self.run(opts={})
      new(DEFAULT_CONFIG.merge!(opts)).send(opts["default_task"])
    end

    def self.new(opts={})
      # include the correct fetch strategy
      include EY::Strategies.const_get(opts["strategy"])::Helpers
      super
    end

    # default task
    def update
      EY::Server.repository_cache = repository_cache
      update_repository_cache

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
      Server.all.each do |server|
        puts "~ Deploying with #{deploy_command(server)}"
        server.run(deploy_command(server))
      end
    end

    def deploy_command(server)
      "eysd deploy #{server.default_task} -a #{app} #{migrate_option}"
    end

    def migrate_option
      if migrate?
        %|--migrate \\"#{migration_command}\\"|
      else
        "--no-migrate"
      end
    end

  end
end
