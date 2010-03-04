# stolen wholesale from capistrano, thanks Jamis!
require 'fileutils'
require 'json'

module EY
  class DeployBase < Task
    # task, default
    def deploy
      puts "~> Starting full deploy"
      Dir.chdir c.deploy_to

      copy_repository_cache
      bundle
      symlink
      migrate
      restart
      cleanup

      puts "~> finalizing deploy"
    end

    # task, default
    def symlink_only
      puts "~> Starting symlink deploy"
      Dir.chdir c.deploy_to

      copy_repository_cache
      bundle
      symlink
      cleanup

      puts "~> finalizing deploy"
    end

    # task
    def restart
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

    # task
    def bundle
      if File.exist?("#{c.latest_release}/Gemfile")
        puts "~> Gemfile detected, bundling gems"
        Dir.chdir(c.latest_release) do
          system("bundle install")
        end
      end
    end

    # task
    def cleanup
      puts "~> cleaning up old releases"
      releases = c.all_releases
      3.times {releases.shift}
      releases.each do |rel|
        FileUtils.rm_rf rel
      end
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
      if c.migrate?
        callback(:before_restart)
        sudo "ln -nfs #{c.shared_path}/config/database.yml #{c.latest_release}/config/database.yml"
        sudo "ln -nfs #{c.shared_path}/log #{c.latest_release}/log"
        puts "~> Migrating: cd #{c.latest_release} && sudo -u #{c.user} #{c.framework_envs} #{c.migration_command}"
        sudo("chown -R #{c.user}:#{c.group} #{c.latest_release}")
        sudo("cd #{c.latest_release} && sudo -u #{c.user} #{c.framework_envs} #{c.migration_command}")
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

    def initialize(*args)
      super
      class << config
        def latest_release
          all_releases.last
        end

        def previous_release(current=latest_release)
          index = all_releases.index(current)
          all_releases[index-1]
        end

        def oldest_release
          all_releases.first
        end

        def all_releases
          Dir.glob("#{release_dir}/*").sort
        end

        def framework_envs
          "RAILS_ENV=#{environment} RACK_ENV=#{environment} MERB_ENV=#{environment}"
        end

        def current_path
          File.join(deploy_to, "current")
        end

        def shared_path
          File.join(deploy_to, "shared")
        end

        def release_dir
          File.join(deploy_to, "releases")
        end

        def release_path
          @release_path ||= File.join(release_dir, Time.now.utc.strftime("%Y%m%d%H%M%S"))
        end

        def exclusions
          copy_exclude.map { |e| %|--exclude="#{e}"| }.join(' ')
        end
      end
    end
  end

  class Deploy < DeployBase
    def self.run(opts={})
      dep = new(EY::Deploy::Configuration.new(opts))
      dep.require_custom_tasks
      dep.send(opts["default_task"])
    end
  end
end