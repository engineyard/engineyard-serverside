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
      bundle
      symlink
      migrate
      restart
      cleanup

      puts "~> finalizing deploy"
    end

    # task
    def push_code
      EY::Server.all.each do |server|
        server.push_code
      end
    end

    # task
    def restart
      roles :app_master, :app, :solo do
        restart_command = case c.stack
        when "nginx_unicorn"
          "/etc/init.d/unicorn_#{c.app} restart"
        when "nginx_mongrel"
          "monit restart all -g #{c.app}"
        when "nginx_passenger", "apache_passenger"
          "touch #{c.latest_release}/tmp/restart.txt"
        end
        if restart_command
          puts "~> restarting app: #{c.latest_release}"
          sudo("cd #{c.current_path} && INLINEDIR=/tmp #{c.framework_envs} #{restart_command}")
        end
        callback(:after_restart)
      end
    end

    # task
    def bundle
      if File.exist?("#{c.latest_release}/Gemfile")
        puts "~> Gemfile detected, bundling gems"
        run %|cd #{c.latest_release} && bundle install|
      end
    end

    # task
    def cleanup
      puts "~> cleaning up old releases"
      sudo "ls #{c.release_dir} | head -n -3 | xargs -I{} rm -rf #{c.release_dir}/{}"
    end

    # task
    def rollback
      puts "~> rolling back to previous release"
      symlink(c.previous_release)
      FileUtils.rm_rf c.latest_release
      puts "~> restarting with previous release"
      restart
    end

    # task
    def migrate
      roles :app_master, :solo do
        if c.migrate?
          callback(:before_restart)
          sudo "ln -nfs #{c.shared_path}/config/database.yml #{c.latest_release}/config/database.yml"
          sudo "ln -nfs #{c.shared_path}/log #{c.latest_release}/log"
          puts "~> Migrating: cd #{c.latest_release} && sudo -u #{c.user} #{c.framework_envs} #{c.migration_command}"
          sudo("chown -R #{c.user}:#{c.group} #{c.latest_release}")
          sudo("cd #{c.latest_release} && sudo -u #{c.user} #{c.framework_envs} #{c.migration_command}")
        end
      end
    end

    # task
    def copy_repository_cache
      puts "~> copying to #{c.release_path}"
      sudo("mkdir -p #{c.release_path} && rsync -aq #{c.exclusions} #{c.repository_cache}/* #{c.release_path}")

      puts "~> ensuring proper ownership"
      sudo("chown -R #{c.user}:#{c.group} #{c.deploy_to}")
    end

    # task
    def symlink(release_to_link=c.latest_release)
      callback(:before_symlink)
      puts "~> symlinking code"
      symlink = false
      begin
        sudo [ "chmod -R g+w #{release_to_link}",
          "rm -rf #{release_to_link}/log #{release_to_link}/public/system #{release_to_link}/tmp/pids",
          "mkdir -p #{release_to_link}/tmp",
          "ln -nfs #{c.shared_path}/log #{release_to_link}/log",
          "mkdir -p #{release_to_link}/public",
          "mkdir -p #{release_to_link}/config",
          "ln -nfs #{c.shared_path}/system #{release_to_link}/public/system",
          "ln -nfs #{c.shared_path}/pids #{release_to_link}/tmp/pids",
          "ln -nfs #{c.shared_path}/config/database.yml #{release_to_link}/config/database.yml",
          "chown -R #{c.user}:#{c.group} #{release_to_link}"
          ].join(" && ")

        symlink = true
        sudo "rm -f #{c.current_path} && ln -nfs #{release_to_link} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
      rescue => e
        sudo "rm -f #{c.current_path} && ln -nfs #{c.previous_release(release_to_link)} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}" if symlink
        sudo "rm -rf #{release_to_link}"
        raise e
      end
    end

    # before_symlink
    # before_restart
    def callback(what)
      if File.exist?("#{c.latest_release}/deploy/#{what}.rb")
        Dir.chdir(c.latest_release) do
          puts "~> running deploy hook: deploy/#{what}.rb"
          instance_eval(IO.read("#{c.latest_release}/deploy/#{what}.rb"))
        end
      end
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

      dep = new(conf)
      dep.require_custom_tasks
      dep.send(opts["default_task"])
    end
  end
end