# stolen wholesale from capistrano, thanks Jamis!
require 'base64'
require 'fileutils'
require 'json'
require 'engineyard-serverside/rails_asset_support'

module EY
  module Serverside
    class DeployBase < Task
      include LoggedOutput
      include ::EY::Serverside::RailsAssetSupport

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
        check_repository

        with_failed_release_cleanup do
          create_revision_file
          run_with_callbacks(:bundle)
          symlink_configs
          conditionally_enable_maintenance_page
          run_with_callbacks(:migrate)
          run_with_callbacks(:compile_assets) # defined in RailsAssetSupport
          callback(:before_symlink)
          # We don't use run_with_callbacks for symlink because we need
          # to clean up manually if it fails.
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

      def check_repository
        if gemfile?
          info "~> Gemfile found."
          if lockfile
            info "~> Gemfile.lock found."
            unless lockfile.any_database_adapter?
              warning <<-WARN
Gemfile.lock does not contain a recognized database adapter.
A database-adapter gem such as mysql2, mysql, or do_mysql was expected.
This can prevent applications that use MySQL or PostreSQL from booting.

To fix, add any needed adapter to your Gemfile, bundle, commit, and redeploy.
Applications that don't use MySQL or PostgreSQL can safely ignore this warning.
              WARN
            end
          else
            warning <<-WARN
Gemfile.lock is missing!
You can get different versions of gems in production than what you tested with.
You can get different versions of gems on every deployment even if your Gemfile hasn't changed.
Deploying will take longer.

To fix this problem, commit your Gemfile.lock to your repository and redeploy.
            WARN
          end
        else
          info "~> No Gemfile. Deploying without bundler support."
        end
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

      def clean_environment
        # GIT_SSH needs to be defined in the environment for customers with private bundler repos in their Gemfile.
        %Q[export GIT_SSH="ssh -o 'StrictHostKeyChecking no' -o 'PasswordAuthentication no' -o 'LogLevel DEBUG' -i ~/.ssh/#{c.app}-deploy-key" && unset BUNDLE_PATH BUNDLE_FROZEN BUNDLE_WITHOUT BUNDLE_BIN BUNDLE_GEMFILE]
      end

      # task
      def bundle
        check_ruby_bundler
        check_node_npm
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
          info "~> Restarting with previous release."
          with_maintenance_page { run_with_callbacks(:restart) }
        else
          info "~> Already at oldest release, nothing to roll back to."
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

        info "~> Ensuring proper ownership."
        sudo("chown -R #{c.user}:#{c.group} #{c.deploy_to}")
      end

      def create_revision_file
        run create_revision_file_command
      end

      def symlink_configs(release_to_link=c.release_path)
        info "~> Preparing shared resources for release."
        symlink_tasks(release_to_link).each do |what, cmd|
          info "~> #{what}"
          run(cmd)
        end
        owner = [c.user, c.group].join(':')
        info "~> Setting ownership to #{owner}"
        sudo "chown -R #{owner} #{release_to_link}"
      end

      def symlink_tasks(release_to_link)
        [
          ["Set group write permissions", "chmod -R g+w #{release_to_link}"],
          ["Remove revision-tracked shared directories from deployment", "rm -rf #{release_to_link}/log #{release_to_link}/public/system #{release_to_link}/tmp/pids"],
          ["Create tmp directory", "mkdir -p #{release_to_link}/tmp"],
          ["Symlink shared log directory", "ln -nfs #{c.shared_path}/log #{release_to_link}/log"],
          ["Create public directory if needed", "mkdir -p #{release_to_link}/public"],
          ["Create config directory if needed", "mkdir -p #{release_to_link}/config"],
          ["Create system directory if needed", "ln -nfs #{c.shared_path}/system #{release_to_link}/public/system"],
          ["Symlink shared pids directory", "ln -nfs #{c.shared_path}/pids #{release_to_link}/tmp/pids"],
          ["Symlink other shared config files", "find #{c.shared_path}/config -type f -not -name 'database.yml' -exec ln -s {} #{release_to_link}/config \\;"],
          ["Symlink mongrel_cluster.yml", "ln -nfs #{c.shared_path}/config/mongrel_cluster.yml #{release_to_link}/config/mongrel_cluster.yml"],
          ["Symlink database.yml", "ln -nfs #{c.shared_path}/config/database.yml #{release_to_link}/config/database.yml"],
          ["Symlink newrelic.yml if needed", "if [ -f \"#{c.shared_path}/config/newrelic.yml\" ]; then ln -nfs #{c.shared_path}/config/newrelic.yml #{release_to_link}/config/newrelic.yml; fi"],
        ]
      end

      # task
      def symlink(release_to_link=c.release_path)
        info "~> Symlinking code."
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

      def gemfile?
        File.exist?("#{c.release_path}/Gemfile")
      end

      def base_callback_command_for(what)
        [serverside_bin, 'hook', what.to_s,
          '--app', config.app.to_s,
          '--release-path', config.release_path.to_s,
          '--framework-env', c.environment.to_s,
        ].compact
      end

      def serverside_bin
        basedir = File.expand_path('../../..', __FILE__)
        File.join(basedir, 'bin', 'engineyard-serverside')
      end

      def puts_deploy_failure
        if @cleanup_failed
          info "~> [Relax] Your site is running new code, but clean up of old deploys failed."
        elsif @maintenance_up
          info "~> [Attention] Maintenance page still up, consider the following before removing:"
          info " * Deploy hooks ran. This might cause problems for reverting to old code." if @callbacks_reached
          info " * Migrations ran. This might cause problems for reverting to old code." if @migrations_reached
          if @symlink_changed
            info " * Your new code is symlinked as current."
          else
            info " * Your old code is still symlinked as current."
          end
          info " * Application servers failed to restart." if @restart_failed
          info ""
          info "~> Need help? File a ticket for support."
        else
          info "~> [Relax] Your site is still running old code and nothing destructive has occurred."
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

      def bundler_config
        version = LockfileParser.default_version
        options = [
          "--path #{c.bundled_gems_path}",
          "--binstubs #{c.binstubs_path}",
          "--without #{c.bundle_without}"
        ]

        if lockfile
          version = lockfile.bundler_version
          options.unshift('--deployment') # deployment mode is not supported without a Gemfile.lock
        end

        return [version, options.join(' ')]
      end

      def lockfile
        lockfile_path = File.join(c.release_path, "Gemfile.lock")
        if File.exist?(lockfile_path)
          @lockfile_parser ||= LockfileParser.new(File.read(lockfile_path))
        else
          nil
        end
      end

      def check_ruby_bundler
        if gemfile?
          info "~> Bundling gems..."

          bundler_version, install_switches = bundler_config

          sudo "#{clean_environment} && #{serverside_bin} install_bundler #{bundler_version}"

          ruby_version   = `ruby -v`
          system_version = `uname -m`

          if File.directory?(c.bundled_gems_path)
            rebundle = false

            rebundle = true if File.exist?(c.ruby_version_file)   && File.read(c.ruby_version_file)   != ruby_version
            rebundle = true if File.exist?(c.system_version_file) && File.read(c.system_version_file) != system_version

            if rebundle
              info "~> Ruby version change detected, cleaning bundled gems"
              run "rm -Rf #{c.bundled_gems_path}"
            end
          end

          run "#{clean_environment} && cd #{c.release_path} && ruby -S bundle _#{bundler_version}_ install #{install_switches}"

          run "mkdir -p #{c.bundled_gems_path} && ruby -v > #{c.ruby_version_file} && uname -m > #{c.system_version_file}"
        end
      end

      def check_node_npm
        if File.exist?("#{c.release_path}/package.json")
          unless run("which npm")
            abort "*** [Error] package.json detected, but npm was not installed"
          else
            info "~> package.json detected, installing npm packages"
            run "cd #{c.release_path} && npm install"
          end
        end
      end
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
