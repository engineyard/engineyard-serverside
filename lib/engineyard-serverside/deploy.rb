# stolen wholesale from capistrano, thanks Jamis!
require 'base64'
require 'fileutils'
require 'json'

module EY
  module Serverside
    class DeployBase < Task
      include LoggedOutput

      # default task
      def deploy
        debug "Starting deploy at #{Time.now.asctime}"
        update_repository_cache
        cached_deploy
      end

      def cached_deploy
        debug "Deploying app from cached copy at #{Time.now.asctime}"
        require_custom_tasks
        push_code

        info "~> Starting full deploy"
        copy_repository_cache

        with_failed_release_cleanup do
          create_revision_file
          run_with_callbacks(:bundle)
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

      def restart_with_maintenance_page
        require_custom_tasks
        conditionally_enable_maintenance_page
        restart
        disable_maintenance_page
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
          maint_page_dir = File.join(c.shared_path, "system")
          visible_maint_page = File.join(maint_page_dir, "maintenance.html")
          run Escape.shell_command(['mkdir', '-p', maint_page_dir])
          run Escape.shell_command(['cp', maintenance_file, visible_maint_page])
        end
      end

      def conditionally_enable_maintenance_page
        if c.migrate? || required_downtime_stack?
          enable_maintenance_page
        end
      end

      def required_downtime_stack?
        %w[ nginx_mongrel glassfish ].include? c.stack
      end

      def disable_maintenance_page
        @maintenance_up = false
        roles :app_master, :app, :solo do
          run "rm -f #{File.join(c.shared_path, "system", "maintenance.html")}"
        end
      end

      def run_with_callbacks(task)
        callback("before_#{task}")
        send(task)
        callback("after_#{task}")
      end

      # task
      def push_code
        info "~> Pushing code to all servers"
        barrier *(EY::Serverside::Server.all.map do |server|
          need_later { server.sync_directory(config.repository_cache) }
        end)
      end

      # task
      def restart
        @restart_failed = true
        info "~> Restarting app servers"
        roles :app_master, :app, :solo do
          run(restart_command)
        end
        @restart_failed = false
      end

      def restart_command
        "/engineyard/bin/app_#{c.app} deploy"
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
                                bundler_09_installer(default_09_bundler)
                              end

          sudo "#{$0} _#{EY::Serverside::VERSION}_ install_bundler #{bundler_installer.version}"

          run "exec ssh-agent bash -c 'ssh-add #{c.ssh_private_key} && cd #{c.release_path} && bundle _#{bundler_installer.version}_ install #{bundler_installer.options}'"
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
          rolled_back_release = c.latest_release
          c.release_path = c.previous_release(rolled_back_release)

          revision = File.read(File.join(c.release_path, 'REVISION')).strip
          info "~> Rolling back to previous release: #{short_log_message(revision)}"

          run_with_callbacks(:symlink)
          sudo "rm -rf #{rolled_back_release}"
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
          cmd = "cd #{c.release_path} && PATH=#{c.binstubs_path}:$PATH #{c.framework_envs} #{c.migration_command}"
          info "~> Migrating: #{cmd}"
          run(cmd)
        end
      end

      # task
      def copy_repository_cache
        info "~> Copying to #{c.release_path}"
        run("mkdir -p #{c.release_path} && rsync -aq #{c.exclusions} #{c.repository_cache}/ #{c.release_path}")

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
          "find #{c.shared_path}/config -type f -exec ln -s {} #{release_to_link}/config \\;",
          "ln -nfs #{c.shared_path}/config/database.yml #{release_to_link}/config/database.yml",
          "ln -nfs #{c.shared_path}/config/mongrel_cluster.yml #{release_to_link}/config/mongrel_cluster.yml",
        ].each do |cmd|
          run cmd
        end

        sudo "chown -R #{c.user}:#{c.group} #{release_to_link}"
        run "if [ -f \"#{c.shared_path}/config/newrelic.yml\" ]; then ln -nfs #{c.shared_path}/config/newrelic.yml #{release_to_link}/config/newrelic.yml; fi"
      end

      # task
      def symlink(release_to_link=c.release_path)
        info "~> Symlinking code"
        run "rm -f #{c.current_path} && ln -nfs #{release_to_link} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
        @symlink_changed = true
      rescue Exception
        sudo "rm -f #{c.current_path} && ln -nfs #{c.previous_release(release_to_link)} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
        @symlink_changed = false
        raise
      end

      def callback(what)
        @callbacks_reached ||= true
        if File.exist?("#{c.release_path}/deploy/#{what}.rb")
          run Escape.shell_command(base_callback_command_for(what)) do |server, cmd|
            per_instance_args = [
              '--current-roles', server.roles.join(' '),
              '--config', c.to_json,
            ]
            per_instance_args << '--current-name' << server.name.to_s if server.name
            cmd << " " << Escape.shell_command(per_instance_args)
          end
        end
      end

      protected

      def base_callback_command_for(what)
        [$0, version_specifier, 'hook', what.to_s,
          '--app', config.app.to_s,
          '--release-path', config.release_path.to_s,
          '--framework-env', c.environment.to_s,
        ].compact
      end

      def version_specifier
        "_#{EY::Serverside::VERSION}_"
      end


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
        sudo "rm -rf #{c.release_path}"
        raise
      end

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
        info "!> This deployment will use bundler #{default_09_bundler} to run 'bundle install'."
        info "!>"
      end

      def get_bundler_installer(lockfile)
        parser = LockfileParser.new(File.read(lockfile))
        case parser.lockfile_version
        when :bundler09
          bundler_09_installer(parser.bundler_version || default_09_bundler)
        when :bundler10
          bundler_10_installer(parser.bundler_version || default_10_bundler)
        else
          raise "Unknown lockfile version #{parser.lockfile_version}"
        end
      end
      public :get_bundler_installer

      def bundler_09_installer(version)
        BundleInstaller.new(version, '--without=development --without=test')
      end

      def bundler_10_installer(version)
        BundleInstaller.new(version,
          "--deployment --path #{c.shared_path}/bundled_gems --binstubs #{c.binstubs_path} --without development test")
      end

      def default_09_bundler() "0.9.26" end
      def default_10_bundler() "1.0.0"  end

    end   # DeployBase

    class Deploy < DeployBase
      def self.new(config)
        # include the correct fetch strategy
        include EY::Serverside::Strategies.const_get(config.strategy)::Helpers
        super
      end
    end

  end
end
