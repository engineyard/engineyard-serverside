# stolen wholesale from capistrano, thanks Jamis!
require 'base64'
require 'fileutils'
require 'json'
require 'engineyard-serverside/rails_asset_support'

module EY
  module Serverside
    class DeployBase < Task
      include ::EY::Serverside::RailsAssetSupport

      # default task
      def deploy
        shell.status "Starting deploy at #{shell.start_time.asctime}"
        update_repository_cache
        cached_deploy
      end

      def cached_deploy
        shell.status "Deploying app from cached copy at #{Time.now.asctime}"
        require_custom_tasks
        load_ey_yml
        push_code

        shell.status "Starting full deploy"
        copy_repository_cache
        check_repository

        with_failed_release_cleanup do
          create_revision_file
          run_with_callbacks(:bundle)
          setup_services
          check_for_ey_config
          symlink_configs
          setup_sqlite3_if_necessary
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
        conditionally_disable_maintenance_page

        cleanup_old_releases
        shell.status "Finished deploy at #{Time.now.asctime}"
      rescue Exception
        shell.status "Finished failing to deploy at #{Time.now.asctime}"
        puts_deploy_failure
        raise
      end

      def update_repository_cache
        strategy.update_repository_cache
      end

      def create_revision_file_command
        strategy.create_revision_file_command(config.release_path)
      end

      def short_log_message(revision)
        strategy.short_log_message(revision)
      end

      def parse_configured_services
        result = YAML.load_file "#{c.shared_path}/config/ey_services_config_deploy.yml"
        return {} unless result.is_a?(Hash)
        result
      rescue
        {}
      end

      def check_for_ey_config
        if gemfile? && lockfile
          configured_services = parse_configured_services
          if !configured_services.empty? && !lockfile.has_ey_config?
            shell.warning "Gemfile.lock does not contain ey_config. Add it to get EY::Config access to: #{configured_services.keys.join(', ')}."
          end
        end
      end

      def check_repository
        if gemfile?
          shell.status "Gemfile found."
          if lockfile
            shell.status "Gemfile.lock found."
            if !config.ignore_database_adapter_warning? && !lockfile.any_database_adapter?
              shell.warning <<-WARN
Gemfile.lock does not contain a recognized database adapter.
A database-adapter gem such as mysql2, mysql, or do_mysql was expected.
This can prevent applications that use MySQL or PostreSQL from booting.

To fix, add any needed adapter to your Gemfile, bundle, commit, and redeploy.
Applications not using MySQL or PostgreSQL can safely ignore this warning by
adding ignore_database_adapter_warning: true to the application's ey.yml file
under this environment's name and adding the file to your repository.
              WARN
            end
          else
            shell.warning <<-WARN
Gemfile.lock is missing!
You can get different versions of gems in production than what you tested with.
You can get different versions of gems on every deployment even if your Gemfile hasn't changed.
Deploying will take longer.

To fix this problem, commit your Gemfile.lock to your repository and redeploy.
            WARN
          end
        else
          shell.status "No Gemfile. Deploying without bundler support."
        end
      end

      def restart_with_maintenance_page
        require_custom_tasks
        with_maintenance_page { restart }
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
        maintenance_page_candidates << File.expand_path("default_maintenance_page.html", File.dirname(__FILE__))

        # put in the maintenance page
        maintenance_file = maintenance_page_candidates.detect do |file|
          File.exists?(file)
        end

        shell.status "Enabling maintenance page."
        @maintenance_up = true
        roles :app_master, :app, :solo do
          run Escape.shell_command(['mkdir', '-p', File.dirname(c.maintenance_page_enabled_path)])
          run Escape.shell_command(['cp', maintenance_file, c.maintenance_page_enabled_path])
        end
      end

      def conditionally_enable_maintenance_page
        if c.enable_maintenance_page?
          enable_maintenance_page
        else
          explain_not_enabling_maintenance_page
        end
      end

      def explain_not_enabling_maintenance_page
        if c.migrate?
          if !c.enable_maintenance_page_on_migrate? && !c.enable_maintenance_page_on_restart?
            shell.status "Skipping maintenance page. (maintenance_on_migrate is false in ey.yml)"
            shell.notice "[Caution] No maintenance migrations must be non-destructive!"
            shell.notice "Requests may be served during a partially migrated state."
          end
        else
          if c.required_downtime_stack? && !c.enable_maintenance_page_on_restart?
            shell.status "Skipping maintenance page. (maintenance_on_restart is false in ey.yml, overriding recommended default)"
            unless File.exist?(c.maintenance_page_enabled_path)
              shell.warning <<-WARN
No maintenance page! Brief downtime may be possible during restart.
This application stack does not support no-downtime restarts.
              WARN
            end
          elsif !c.required_downtime_stack?
            shell.status "Skipping maintenance page. (no-downtime restarts supported)"
          end
        end
      end

      def disable_maintenance_page
        shell.status "Removing maintenance page."
        @maintenance_up = false
        roles :app_master, :app, :solo do
          run "rm -f #{c.maintenance_page_enabled_path}"
        end
      end

      def conditionally_disable_maintenance_page
        if c.disable_maintenance_page?
          disable_maintenance_page
        elsif File.exists?(c.maintenance_page_enabled_path)
          shell.notice "[Attention] Maintenance page is still up.\nYou must remove it manually using `ey web enable`."
        end
      end

      def run_with_callbacks(task)
        callback("before_#{task}")
        send(task)
        callback("after_#{task}")
      end

      # task
      def push_code
        shell.status "Pushing code to all servers"
        commands = EY::Serverside::Server.all.reject { |server| server.local? }.map do |server|
          cmd = server.sync_directory_command(config.repository_cache)
          proc { shell.logged_system(cmd) }
        end
        futures = EY::Serverside::Future.call(commands)
        EY::Serverside::Future.success?(futures)
      end

      # task
      def restart
        @restart_failed = true
        shell.status "Restarting app servers"
        roles :app_master, :app, :solo do
          run(restart_command)
        end
        @restart_failed = false
      end

      def restart_command
        %{LANG="en_US.UTF-8" /engineyard/bin/app_#{c.app} deploy}
      end

      # GIT_SSH needs to be defined in the environment for customers with private bundler repos in their Gemfile.
      def clean_environment
        %Q[export GIT_SSH="#{ssh_executable}" && export LANG="en_US.UTF-8" && unset RUBYOPT BUNDLE_PATH BUNDLE_FROZEN BUNDLE_WITHOUT BUNDLE_BIN BUNDLE_GEMFILE]
      end

      # create ssh wrapper on all servers
      def ssh_executable
        @ssh_executable ||= begin
                              roles :app_master, :app, :solo, :util do
                                run(generate_ssh_wrapper)
                              end
                              ssh_wrapper_path
                            end
      end

      # We specify 'IdentitiesOnly' to avoid failures on systems with > 5 private keys available.
      # We set UserKnownHostsFile to /dev/null because StrickHostKeyChecking no doesn't
      # ignore existing entries in known_hosts; we want to actively ignore all such.
      # Learned this at http://lists.mindrot.org/pipermail/openssh-unix-dev/2009-February/027271.html
      # (Thanks Jim L.)
      def generate_ssh_wrapper
        path = ssh_wrapper_path
        <<-SCRIPT
mkdir -p #{File.dirname(path)}
[[ -x #{path} ]] || cat > #{path} <<'SSH'
#!/bin/sh
unset SSH_AUTH_SOCK
ssh -o CheckHostIP=no -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o LogLevel=INFO -o IdentityFile=#{c.ssh_identity_file} -o IdentitiesOnly=yes $*
SSH
chmod 0700 #{path}
        SCRIPT
      end

      def ssh_wrapper_path
        "#{c.shared_path}/config/#{c.app}-ssh-wrapper"
      end

      # task
      def bundle
        roles :app_master, :app, :solo, :util do
          check_ruby_bundler
          check_node_npm
        end
      end

      # task
      def cleanup_old_releases
        clean_release_directory(c.release_dir)
        clean_release_directory(c.failed_release_dir)
      end

      # Remove all but the most-recent +count+ releases from the specified
      # release directory.
      # IMPORTANT: This expects the release directory naming convention to be
      # something with a sensible lexical order. Violate that at your peril.
      def clean_release_directory(dir, count = 3)
        @cleanup_failed = true
        ordinal = count.succ.to_s
        shell.status "Cleaning release directory: #{dir}"
        sudo "ls -r #{dir} | tail -n +#{ordinal} | xargs -I@ rm -rf #{dir}/@"
        @cleanup_failed = false
      end

      # task
      def rollback
        if rolled_back_release = c.rollback_paths!
          begin
            shell.status "Rolling back to previous release: #{short_log_message(c.active_revision)}"
            run_with_callbacks(:symlink)
            sudo "rm -rf #{rolled_back_release}"
            bundle
            shell.status "Restarting with previous release."
            with_maintenance_page { run_with_callbacks(:restart) }
            shell.status "Finished rollback at #{Time.now.asctime}"
          rescue Exception
            shell.status "Failed to rollback at #{Time.now.asctime}"
            puts_deploy_failure
            raise
          end
        else
          shell.fatal "Already at oldest release, nothing to roll back to."
          exit(1)
        end
      end

      # task
      def migrate
        return unless c.migrate?
        @migrations_reached = true
        roles :app_master, :solo do
          cmd = "cd #{c.release_path} && PATH=#{c.binstubs_path}:$PATH #{c.framework_envs} #{c.migration_command}"
          shell.status "Migrating: #{cmd}"
          run(cmd)
        end
      end

      # task
      def copy_repository_cache
        shell.status "Copying to #{c.release_path}"
        run("mkdir -p #{c.release_path} #{c.failed_release_dir} && rsync -aq #{c.exclusions} #{c.repository_cache}/ #{c.release_path}")

        shell.status "Ensuring proper ownership."
        sudo("chown -R #{c.user}:#{c.group} #{c.release_path} #{c.failed_release_dir}")
      end

      def create_revision_file
        run create_revision_file_command
      end

      def services_command_check
        "which /usr/local/ey_resin/ruby/bin/ey-services-setup"
      end

      def services_setup_command
        "/usr/local/ey_resin/ruby/bin/ey-services-setup #{config.app}"
      end

      def setup_services
        shell.status "Setting up external services."
        previously_configured_services = parse_configured_services
        begin
          sudo(services_command_check)
        rescue StandardError => e
          shell.info "Could not setup services. Upgrade your environment to get services configuration."
          return
        end
        sudo(services_setup_command)
      rescue StandardError => e
        unless previously_configured_services.empty?
          shell.warning <<-WARNING
External services configuration not updated. Using previous version.
Deploy again if your services configuration appears incomplete or out of date.
#{e}
          WARNING
        end
      end

      def setup_sqlite3_if_necessary
        if gemfile? && lockfile && lockfile.uses_sqlite3?
          [
           ["Create databases directory if needed", "mkdir -p #{c.shared_path}/databases"],
           ["Creating SQLite database if needed", "touch #{c.shared_path}/databases/#{c.framework_env}.sqlite3"],
           ["Create config directory if needed", "mkdir -p #{c.release_path}/config"],
           ["Generating SQLite config", <<-WRAP],
cat > #{c.shared_path}/config/database.sqlite3.yml<<'YML'
#{c.framework_env}:
  adapter: sqlite3
  database: #{c.shared_path}/databases/#{c.framework_env}.sqlite3
  pool: 5
  timeout: 5000
YML
WRAP
           ["Symlink database.yml", "ln -nfs #{c.shared_path}/config/database.sqlite3.yml #{c.release_path}/config/database.yml"],
          ].each do |what, cmd|
            shell.status "#{what}"
            run(cmd)
          end

          owner = [c.user, c.group].join(':')
          shell.status "Setting ownership to #{owner}"
          sudo "chown -R #{owner} #{c.release_path}"
        end
      end

      def symlink_configs(release_to_link=c.release_path)
        shell.status "Preparing shared resources for release."
        symlink_tasks(release_to_link).each do |what, cmd|
          shell.substatus what
          run(cmd)
        end
        owner = [c.user, c.group].join(':')
        shell.status "Setting ownership to #{owner}"
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
        shell.status "Symlinking code."
        run "rm -f #{c.current_path} && ln -nfs #{release_to_link} #{c.current_path} && find #{c.current_path} -not -user #{c.user} -or -not -group #{c.group} -exec chown #{c.user}:#{c.group} {} +"
        @symlink_changed = true
      rescue Exception
        sudo "rm -f #{c.current_path} && ln -nfs #{c.previous_release(release_to_link)} #{c.current_path} && chown -R #{c.user}:#{c.group} #{c.current_path}"
        @symlink_changed = false
        raise
      end

      def callback(what)
        @callbacks_reached ||= true
        if File.exist?("#{c.release_path}/deploy/#{what}.rb")
          shell.status "Running deploy hook: deploy/#{what}.rb"
          run Escape.shell_command(base_callback_command_for(what)) do |server, cmd|
            per_instance_args = []
            per_instance_args << '--current-roles' << server.roles.join(' ')
            per_instance_args << '--current-name'  << server.name.to_s if server.name
            per_instance_args << '--config'        << c.to_json
            cmd << " " << Escape.shell_command(per_instance_args)
          end
        end
      end

      protected

      # Use [] to access attributes instead of calling methods so
      # that we get nils instead of NoMethodError.
      #
      # Rollback doesn't know about the repository location (nor
      # should it need to), but it would like to use #short_log_message.
      def strategy
        ENV['GIT_SSH'] = ssh_executable
        @strategy ||= config.strategy_class.new(
          shell,
          :repository_cache => config[:repository_cache],
          :app              => config[:app],
          :repo             => config[:repo],
          :ref              => config[:branch]
        )
      end

      def gemfile?
        File.exist?("#{c.release_path}/Gemfile")
      end

      def base_callback_command_for(what)
        cmd =  [serverside_bin, 'hook', what.to_s]
        cmd << '--app'              << config.app
        cmd << '--environment-name' << config.environment_name
        cmd << '--account-name'     << config.account_name
        cmd << '--release-path'     << config.release_path.to_s
        cmd << '--framework-env'    << config.environment.to_s
        cmd << '--verbose' if config.verbose
        cmd
      end

      def serverside_bin
        basedir = File.expand_path('../../..', __FILE__)
        File.join(basedir, 'bin', 'engineyard-serverside')
      end

      def puts_deploy_failure
        if @cleanup_failed
          shell.notice "[Relax] Your site is running new code, but clean up of old deploys failed."
        elsif @maintenance_up
          message = "[Attention] Maintenance page still up, consider the following before removing:\n"
          message << " * Deploy hooks ran. This might cause problems for reverting to old code.\n" if @callbacks_reached
          message << " * Migrations ran. This might cause problems for reverting to old code.\n" if @migrations_reached
          if @symlink_changed
            message << " * Your new code is symlinked as current.\n"
          else
            message << " * Your old code is still symlinked as current.\n"
          end
          message << " * Application servers failed to restart.\n" if @restart_failed
          message << "\n"
          message << "Need help? File a ticket for support.\n"
          shell.notice message
        else
          shell.notice "[Relax] Your site is still running old code and nothing destructive has occurred."
        end
      end

      def with_maintenance_page
        conditionally_enable_maintenance_page
        yield if block_given?
        conditionally_disable_maintenance_page
      end

      def with_failed_release_cleanup
        yield
      rescue Exception
        shell.status "Release #{c.release_path} failed, saving release to #{c.failed_release_dir}."
        sudo "mv #{c.release_path} #{c.failed_release_dir}"
        raise
      end

      def bundler_config
        version = LockfileParser.default_version
        options = [
          "--gemfile #{c.gemfile_path}",
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
          shell.status "Bundling gems..."

          clean_bundle_on_system_version_change

          bundler_version, install_switches = bundler_config
          sudo "#{clean_environment} && #{serverside_bin} install_bundler #{bundler_version}"
          run  "#{clean_environment} && cd #{c.release_path} && ruby -S bundle _#{bundler_version}_ install #{install_switches}"

          write_system_version
        end
      end

      def clean_bundle_on_system_version_change
        # diff exits with 0 for same and 1/2 for different/file not found.
        check_ruby   = "#{c.ruby_version_command} | diff - #{c.ruby_version_file} >/dev/null 2>&1"
        check_system = "#{c.system_version_command} | diff - #{c.system_version_file} >/dev/null 2>&1"
        say_cleaning = "echo 'New deploy or system version change detected, cleaning bundled gems.'"
        clean_bundle = "rm -Rf #{c.bundled_gems_path}"

        run "#{check_ruby} && #{check_system} || (#{say_cleaning} && #{clean_bundle})"
      end

      def write_system_version
        store_ruby_version   = "#{c.ruby_version_command} > #{c.ruby_version_file}"
        store_system_version = "#{c.system_version_command} > #{c.system_version_file}"

        run "mkdir -p #{c.bundled_gems_path} && #{store_ruby_version} && #{store_system_version}"
      end

      def check_node_npm
        if File.exist?("#{c.release_path}/package.json")
          shell.info "~> package.json detected, installing npm packages"
          run "cd #{c.release_path} && npm install"
        end
      end
    end   # DeployBase

    class Deploy < DeployBase
    end
  end
end
