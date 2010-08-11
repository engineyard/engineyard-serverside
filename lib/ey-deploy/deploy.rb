# stolen wholesale from capistrano, thanks Jamis!
require 'base64'
require 'fileutils'
require 'json'

module EY
  class DeployBase < Task
    include LoggedOutput

    # default task
    def deploy
      debug "Starting deploy at #{Time.now.asctime}"
      update_repository_cache
      require_custom_tasks
      push_code

      info "~> Starting full deploy"
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
      debug "Finished deploy at #{Time.now.asctime}"
    rescue Exception
      debug "Finished failing to deploy at #{Time.now.asctime}"
      puts_deploy_failure
      raise
    end

    def enable_maintenance_page
      maintenance_page_candidates = [
        "public/maintenance.html.custom",
        "public/maintenance.html.tmp",
        "public/maintenance.html",
        "public/system/maintenance.html.default",
      ].map do |file|
        File.join(c.latest_release, file)
      end

      # this one is guaranteed to exist
      maintenance_page_candidates <<  File.expand_path(
        "default_maintenance_page.html",
        File.dirname(__FILE__)
        )

      # put in the maintenance page
      maintenance_file = maintenance_page_candidates.detect do |file|
        File.exists?(file)
      end

      @maintenance_up = true
      roles :app_master, :app, :solo do
        visible_maint_page = File.join(c.shared_path, "system", "maintenance.html")
        run "cp '#{maintenance_file}' '#{visible_maint_page}'"
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
      info "~> Pushing code to all servers"
      barrier *(EY::Server.all.map do |server|
        need_later { server.push_code }
      end)
    end

    # task
    def restart
      @restart_failed = true
      info "~> Restarting app servers"
      roles :app_master, :app, :solo do
        restart_command = case c.stack
        when "nginx_unicorn"
          pidfile = "/var/run/engineyard/unicorn_#{c.app}.pid"
          condition = "[ -e #{pidfile} ] && [ ! -d /proc/`cat #{pidfile}` ]"
          sudo("if #{condition}; then rm -f #{pidfile}; fi")
          sudo("/etc/init.d/unicorn_#{c.app} deploy")
        when "nginx_mongrel"
          sudo("monit restart all -g #{c.app}")
        when "nginx_passenger"
          sudo("touch #{c.current_path}/tmp/restart.txt")
        else
          raise "Unknown stack #{c.stack}; restart failed!"
        end
      end
      @restart_failed = false
    end

    # task
    def bundle
      if File.exist?("#{c.release_path}/Gemfile")
        info "~> Gemfile detected, bundling gems"
        lockfile = File.join(c.release_path, "Gemfile.lock")

        bundler_installer = if File.exist?(lockfile)
                              get_bundler_installer(lockfile)
                            else
                              warn_about_missing_lockfile
                              DEFAULT_09_BUNDLER
                            end

        sudo "#{$0} _#{VERSION}_ install_bundler #{bundler_installer.version}"

        run "cd #{c.release_path} && bundle _#{bundler_installer.version}_ install #{bundler_installer.options}"
      end
    end

    # task
    def cleanup_old_releases
      @cleanup_failed = true
      info "~> Cleaning up old releases"
      sudo "ls #{c.release_dir} | head -n -3 | xargs -I{} rm -rf #{c.release_dir}/{}"
      @cleanup_failed = false
    end

    # task
    def rollback
      if c.all_releases.size > 1
        c.release_path = c.previous_release

        revision = File.read(File.join(c.release_path, 'REVISION')).strip
        info "~> Rolling back to previous release: #{short_log_message(revision)}"

        run_with_callbacks(:symlink, c.previous_release)
        cleanup_current_release
        bundle
        info "~> Restarting with previous release"
        with_maintenance_page { run_with_callbacks(:restart) }
      else
        info "~> Already at oldest release, nothing to roll back to"
        exit(1)
      end
    end

    # task
    def migrate
      return unless c.migrate?
      @migrations_reached = true
      roles :app_master, :solo do
        cmd = "cd #{c.release_path} && #{c.framework_envs} #{c.migration_command}"
        info "~> Migrating: #{cmd}"
        run(cmd)
      end
    end

    # task
    def copy_repository_cache
      info "~> Copying to #{c.release_path}"
      sudo("mkdir -p #{c.release_path} && rsync -aq #{c.exclusions} #{c.repository_cache}/ #{c.release_path}")

      info "~> Ensuring proper ownership"
      sudo("chown -R #{c.user}:#{c.group} #{c.deploy_to}")
    end

    def create_revision_file
      run create_revision_file_command
    end

    def symlink_configs(release_to_link=c.release_path)
      info "~> Symlinking configs"
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
    def symlink(release_to_link=c.release_path)
      info "~> Symlinking code"
      sudo "rm -f #{c.current_path} && ln -nfs #{release_to_link} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
      @symlink_changed = true
    rescue Exception
      sudo "rm -f #{c.current_path} && ln -nfs #{c.previous_release(release_to_link)} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
      @symlink_changed = false
      raise
    end

    def callback(what)
      @callbacks_reached ||= true
      if File.exist?("#{c.release_path}/deploy/#{what}.rb")
        eydeploy_path = $0   # invoke others just like we were invoked
        run "#{eydeploy_path} _#{VERSION}_ hook '#{what}' --app '#{config.app}' --release-path #{config.release_path}" do |server, cmd|
          cmd << " --framework-env '#{c.environment}'"
          cmd << " --current-role '#{server.role}'"
          cmd << " --current-name '#{server.name}'" if server.name
          cmd << " --config '#{c[:config]}'" if c.has_key?(:config)
          cmd
        end
      end
    end

    protected

    def puts_deploy_failure
      if @cleanup_failed
        info "~> [Relax] Your site is running new code, but cleaning up old deploys failed"
      elsif @maintenance_up
        info "~> [Attention] Maintenance page still up, consider the following before removing:"
        info " * any deploy hooks ran, be careful if they were destructive" if @callbacks_reached
        info " * any migrations ran, be careful if they were destructive" if @migrations_reached
        if @symlink_changed
          info " * your new code is symlinked as current"
        else
          info " * your old code is still symlinked as current"
        end
        info " * application servers failed to restart" if @restart_failed
      else
        info "~> [Relax] Your site is still running old code and nothing destructive could have occurred"
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
      cleanup_current_release
      raise
    end

    def cleanup_current_release
      sudo "rm -rf #{c.release_path}"
    end

    DEFAULT_09_BUNDLER = '0.9.26'
    DEFAULT_10_BUNDLER = '1.0.0.rc.3'

    def warn_about_missing_lockfile
      info "!>"
      info "!> WARNING: Gemfile.lock is missing!"
      info "!> You can get different gems in production than what you tested with."
      info "!> You can get different gems on every deployment even if your Gemfile hasn't changed."
      info "!> Deploying may take a long time."
      info "!>"
      info "!> Fix this by running \"git add Gemfile.lock; git commit\" and deploying again."
      info "!> If you don't have a Gemfile.lock, run \"bundle lock\" to create one."
      info "!>"
      info "!> This deployment will use bundler #{DEFAULT_09_BUNDLER} to run 'bundle install'."
      info "!>"
    end

    def get_bundler_installer(lockfile)
      parser = LockfileParser.new(File.read(lockfile))
      case parser.lockfile_version
      when :bundler09
        BundleInstaller.new(
          parser.bundler_version || DEFAULT_09_BUNDLER,
          "--without=development --without=test")
      when :bundler10
        BundleInstaller.new(
          parser.bundler_version || DEFAULT_10_BUNDLER,
          "--deployment --path #{c.shared_path}/bundled_gems --without development test"
          )
      else
        raise "Unknown lockfile version #{parser.lockfile_version}"
      end
    end
    public :get_bundler_installer

  end   # DeployBase

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
