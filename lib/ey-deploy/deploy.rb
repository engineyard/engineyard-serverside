# stolen wholesale from capistrano, thanks Jamis!
require 'fileutils'
require 'json'

module EY
  class DeployBase < Task
    # default task
    def deploy
      update_repository_cache
      require_custom_tasks
      push_code

      puts "~> Starting full deploy"
      copy_repository_cache

      with_failed_release_cleanup do
        create_revision_file
        bundle
        symlink_configs
        conditionally_enable_maintenance_page
        run_with_callbacks(:migrate)
        callback(:before_symlink)
        symlink
      end

      callback(:after_symlink)
      run_with_callbacks(:restart)
      disable_maintenance_page

      cleanup_old_releases

      puts "~> finalizing deploy"
    rescue Exception
      puts_deploy_failure
      raise
    end

    def enable_maintenance_page
      # put in the maintenance page
      maintenance_file = ["public/maintenance.html.custom", "public/maintenance.html.tmp", "public/maintenance.html", "public/system/maintenance.html.default"].detect do |file|
        File.exists?(File.join(c.latest_release, file))
      end

      if maintenance_file
        @maintenance_up = true
        roles :app_master, :app, :solo do
          run "cp #{File.join(c.latest_release, maintenance_file)} #{File.join(c.shared_path, "system", "maintenance.html")}"
        end
      end
    end

    def conditionally_enable_maintenance_page
      if c.migrate? || c.stack == "nginx_mongrel"
        enable_maintenance_page
      end
    end

    def disable_maintenance_page
      @maintenance_up = false
      roles :app_master, :app, :solo do
        run "rm -f #{File.join(c.shared_path, "system", "maintenance.html")}"
      end
    end

    def run_with_callbacks(task, *args)
      callback(:"before_#{task}")
      send(task, *args)
      callback(:"after_#{task}")
    end

    # task
    def push_code
      puts "~> Pushing code to all servers"
      EY::Server.all.each do |server|
        server.push_code
      end
    end

    # task
    def restart
      @restart_failed = true
      puts "~> Restarting app servers"
      puts "~> restarting app: #{c.latest_release}"
      roles :app_master, :app, :solo do
        restart_command = case c.stack
        when "nginx_unicorn"
          sudo("/etc/init.d/unicorn_#{c.app} deploy")
        when "nginx_mongrel"
          sudo("monit restart all -g #{c.app}")
        when "nginx_passenger", "apache_passenger"
          sudo("touch #{c.latest_release}/tmp/restart.txt")
        end
      end
      @restart_failed = false
    end

    # task
    def bundle
      roles :app_master, :app, :solo do
        if File.exist?("#{c.latest_release}/Gemfile")
          puts "~> Gemfile detected, bundling gems"
          run "cd #{c.latest_release} && bundle install"
        end
      end
    end

    # task
    def cleanup_old_releases
      @cleanup_failed = true
      puts "~> cleaning up old releases"
      sudo "ls #{c.release_dir} | head -n -3 | xargs -I{} rm -rf #{c.release_dir}/{}"
      @cleanup_failed = false
    end

    # task
    def rollback
      puts "~> rolling back to previous release"
      c.release_path = c.previous_release
      run_with_callbacks(:symlink, c.previous_release)
      FileUtils.rm_rf c.latest_release
      bundle
      puts "~> restarting with previous release"
      with_maintenance_page { run_with_callbacks(:restart) }
    end

    # task
    def migrate
      return unless c.migrate?
      @migrations_reached = true
      roles :app_master, :solo do
        puts "~> migrating"
        cmd = "cd #{c.latest_release} && #{c.framework_envs} #{c.migration_command}"
        puts "~> Migrating: #{cmd}"
        run(cmd)
      end
    end

    # task
    def copy_repository_cache
      puts "~> copying to #{c.release_path}"
      sudo("mkdir -p #{c.release_path} && rsync -aq #{c.exclusions} #{c.repository_cache}/ #{c.release_path}")

      puts "~> ensuring proper ownership"
      sudo("chown -R #{c.user}:#{c.group} #{c.deploy_to}")
    end

    def symlink_configs(release_to_link=c.latest_release)
      puts "~> Symlinking configs"
      [ "chmod -R g+w #{release_to_link}",
        "rm -rf #{release_to_link}/log #{release_to_link}/public/system #{release_to_link}/tmp/pids",
        "mkdir -p #{release_to_link}/tmp",
        "ln -nfs #{c.shared_path}/log #{release_to_link}/log",
        "mkdir -p #{release_to_link}/public",
        "mkdir -p #{release_to_link}/config",
        "ln -nfs #{c.shared_path}/system #{release_to_link}/public/system",
        "ln -nfs #{c.shared_path}/pids #{release_to_link}/tmp/pids",
        "ln -nfs #{c.shared_path}/config/database.yml #{release_to_link}/config/database.yml",
        "ln -nfs #{c.shared_path}/config/mongrel_cluster.yml #{release_to_link}/config/mongrel_cluster.yml",
        "chown -R #{c.user}:#{c.group} #{release_to_link}",
        "if [ -f \"#{c.shared_path}/config/newrelic.yml\" ]; then ln -nfs #{c.shared_path}/config/newrelic.yml #{release_to_link}/config/newrelic.yml; fi",

      ].each do |cmd|
        sudo cmd
      end
    end

    # task
    def symlink(release_to_link=c.latest_release)
      puts "~> symlinking code"
      sudo "rm -f #{c.current_path} && ln -nfs #{release_to_link} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
      @symlink_changed = true
    rescue Exception
      sudo "rm -f #{c.current_path} && ln -nfs #{c.previous_release(release_to_link)} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
      @symlink_changed = false
      raise
    end

    def callback(what)
      @callbacks_reached ||= true
      if File.exist?("#{c.latest_release}/deploy/#{what}.rb")
        eysd_path = $0   # invoke others just like we were invoked
        run "#{eysd_path} hook '#{what}' --app '#{config.app}' --release-path #{config.release_path}"
      end
    end

    protected

    def puts_deploy_failure
      if @cleanup_failed
        puts "~> [Relax] Your site is running new code, but cleaning up old deploys failed"
      elsif @maintenance_up
        puts "~> [Attention] Maintenance page still up, consider the following before removing:"
        puts " * any deploy hooks ran, be careful if they were destructive" if @callbacks_reached
        puts " * any migrations ran, be careful if they were destructive" if @migrations_reached
        if @symlink_changed
          puts " * your new code is symlinked as current"
        else
          puts " * your old code is still symlinked as current"
        end
        puts " * application servers failed to restart" if @restart_failed
      else
        puts "~> [Relax] Your site is still running old code and nothing destructive could have occurred"
      end
    end

    def with_maintenance_page
      conditionally_enable_maintenance_page
      yield if block_given?
      disable_maintenance_page
    end

    def with_failed_release_cleanup
      yield
    rescue Exception
      cleanup_latest_release
      raise
    end

    def cleanup_latest_release
      sudo "rm -rf #{c.latest_release}"
    end
  end

  class Deploy < DeployBase
    def self.new(opts={})
      # include the correct fetch strategy
      include EY::Strategies.const_get(opts.strategy)::Helpers
      super
    end

    def self.run(opts={})
      conf = EY::Deploy::Configuration.new(opts)
      EY::Server.config = conf
      new(conf).send(opts["default_task"])
    end
  end
end
