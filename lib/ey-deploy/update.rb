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
      update_repository_cache

      push_code
      deploy
    end

    # task
    def push_code
      all_servers.each do |server|
        server.push_code
      end
    end

    # task
    def deploy
      all_servers.each do |server|
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

    def all_servers
      (app_slaves + db_servers + util_servers).flatten.uniq
    end

    def app_slaves
      to_servers(Array(node["members"]))
    end

    def db_servers
      to_servers(db_master + db_slaves).each do |server|
        server.default_task = :symlink_only
      end
    end

    def db_master
      to_servers(node["db_host"]).each do |server|
        server.default_task = :symlink_only
      end
    end

    def db_slaves
      to_servers(node["db_slaves"]).each do |server|
        server.default_task = :symlink_only
      end
    end

    def util_servers
      to_servers(node["utility_instances"].map{|util| util["hostname"]}).each do |server|
        server.default_task = :symlink_only
      end
    end

    def to_servers(*args)
      args.flatten.map do |s|
        s.respond_to?(:run) ? s : EY::Server.new(s, repository_cache)
      end
    end
  end
end
