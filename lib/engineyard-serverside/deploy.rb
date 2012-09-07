# stolen wholesale from capistrano, thanks Jamis!
require 'base64'
require 'fileutils'
require 'json'
require 'engineyard-serverside/rails_asset_support'
require 'engineyard-serverside/maintenance'

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
          run_with_callbacks(:compile_assets) # defined in RailsAssetSupport
          enable_maintenance_page
          run_with_callbacks(:migrate)
          callback(:before_symlink)
          # We don't use run_with_callbacks for symlink because we need
          # to clean up manually if it fails.
          symlink
        end

        callback(:after_symlink)
        run_with_callbacks(:restart)
        disable_maintenance_page

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
        strategy.create_revision_file_command(paths.active_release)
      end

      def short_log_message(revision)
        strategy.short_log_message(revision)
      end

      def parse_configured_services
        result = YAML.load_file "#{paths.shared_config}/ey_services_config_deploy.yml"
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
A database-adapter gem such as pg, mysql2, mysql, or do_mysql was expected.
This can prevent applications that use PostgreSQL or MySQL from booting.

To fix, add any needed adapter to your Gemfile, bundle, commit, and redeploy.
Applications not using PostgreSQL or MySQL can safely ignore this warning by
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
        load_ey_yml
        enable_maintenance_page
        restart
        disable_maintenance_page
      end

      def enable_maintenance_page
        maintenance.conditionally_enable
      end

      def disable_maintenance_page
        maintenance.conditionally_disable
      end

      def run_with_callbacks(task)
        callback("before_#{task}")
        send(task)
        callback("after_#{task}")
      end

      # task
      def push_code
        shell.status "Pushing code to all servers"
        commands = servers.remote.map do |server|
          cmd = server.sync_directory_command(paths.repository_cache)
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
        %{LANG="en_US.UTF-8" /engineyard/bin/app_#{config.app} deploy}
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
                              paths.ssh_wrapper
                            end
      end

      # We specify 'IdentitiesOnly' to avoid failures on systems with > 5 private keys available.
      # We set UserKnownHostsFile to /dev/null because StrickHostKeyChecking no doesn't
      # ignore existing entries in known_hosts; we want to actively ignore all such.
      # Learned this at http://lists.mindrot.org/pipermail/openssh-unix-dev/2009-February/027271.html
      # (Thanks Jim L.)
      def generate_ssh_wrapper
        path = paths.ssh_wrapper
        <<-SCRIPT
mkdir -p #{path.dirname}
[[ -x #{path} ]] || cat > #{path} <<'SSH'
#!/bin/sh
unset SSH_AUTH_SOCK
ssh -o CheckHostIP=no -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o LogLevel=INFO -o IdentityFile=#{paths.deploy_key} -o IdentitiesOnly=yes $*
SSH
chmod 0700 #{path}
        SCRIPT
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
        clean_release_directory(paths.releases)
        clean_release_directory(paths.releases_failed)
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
        if config.rollback_paths!
          begin
            rolled_back_release = paths.latest_release
            shell.status "Rolling back to previous release: #{short_log_message(config.active_revision)}"
            run_with_callbacks(:symlink)
            sudo "rm -rf #{rolled_back_release}"
            bundle
            shell.status "Restarting with previous release."
            enable_maintenance_page
            run_with_callbacks(:restart)
            disable_maintenance_page
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
        return unless config.migrate?
        @migrations_reached = true
        cmd = "cd #{paths.active_release} && PATH=#{paths.binstubs}:$PATH #{config.framework_envs} #{config.migration_command}"
        roles :app_master, :solo do
          shell.status "Migrating: #{cmd}"
          run(cmd)
        end
      end

      # task
      def copy_repository_cache
        shell.status "Copying to #{paths.active_release}"
        exclusions = Array(config.copy_exclude).map { |e| %|--exclude="#{e}"| }.join(' ')
        run("mkdir -p #{paths.active_release} #{paths.releases_failed} #{paths.shared_config} && rsync -aq #{exclusions} #{paths.repository_cache}/ #{paths.active_release}")

        shell.status "Ensuring proper ownership."
        sudo("chown -R #{config.user}:#{config.group} #{paths.active_release} #{paths.releases_failed}")
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
           ["Create databases directory if needed", "mkdir -p #{paths.shared}/databases"],
           ["Creating SQLite database if needed", "touch #{paths.shared}/databases/#{config.framework_env}.sqlite3"],
           ["Create config directory if needed", "mkdir -p #{paths.active_release_config}"],
           ["Generating SQLite config", <<-WRAP],
cat > #{paths.shared_config}/database.sqlite3.yml<<'YML'
#{config.framework_env}:
  adapter: sqlite3
  database: #{paths.shared}/databases/#{config.framework_env}.sqlite3
  pool: 5
  timeout: 5000
YML
WRAP
           ["Symlink database.yml", "ln -nfs #{paths.shared_config}/database.sqlite3.yml #{paths.active_release_config}/database.yml"],
          ].each do |what, cmd|
            shell.status "#{what}"
            run(cmd)
          end

          owner = [config.user, config.group].join(':')
          shell.status "Setting ownership to #{owner}"
          sudo "chown -R #{owner} #{paths.active_release}"
        end
      end

      def symlink_configs
        shell.status "Preparing shared resources for release."
        symlink_tasks.each do |what, cmd|
          shell.substatus what
          run(cmd)
        end
        owner = [config.user, config.group].join(':')
        shell.status "Setting ownership to #{owner}"
        sudo "chown -R #{owner} #{paths.active_release}"
      end

      def symlink_tasks
        [
          ["Set group write permissions",           "chmod -R g+w #{paths.active_release}"],
          ["Remove symlinked shared directories",   "rm -rf #{paths.active_log} #{paths.public_system} #{paths.active_release}/tmp/pids"],
          ["Create tmp directory",                  "mkdir -p #{paths.active_release}/tmp"],
          ["Create public directory",               "mkdir -p #{paths.public}"],
          ["Create config directory",               "mkdir -p #{paths.active_release_config}"],
          ["Symlink shared log directory",          "ln -nfs #{paths.shared_log} #{paths.active_log}"],
          ["Lymlink pubilc system directory",       "ln -nfs #{paths.shared_system} #{paths.public_system}"],
          ["Symlink shared pids directory",         "ln -nfs #{paths.shared}/pids #{paths.active_release}/tmp/pids"],
          ["Symlink database.yml",                  "ln -nfs #{paths.shared_config}/database.yml #{paths.active_release_config}/database.yml"],
          ["Symlink other shared config files",     "find #{paths.shared_config} -type f -not -name 'database.yml' -exec ln -s {} #{paths.active_release_config} \\;"],
          ["Symlink newrelic.yml if needed",        "if [ -f \"#{paths.shared_config}/newrelic.yml\" ]; then ln -nfs #{paths.shared_config}/newrelic.yml #{paths.active_release_config}/newrelic.yml; fi"],
          ["Symlink mongrel_cluster.yml if needed", "if [ -f \"#{paths.shared_config}/mongrel_cluster.yml\" ]; then ln -nfs #{paths.shared_config}/mongrel_cluster.yml #{paths.active_release_config}/mongrel_cluster.yml; fi"],
        ]
      end

      # task
      def symlink
        shell.status "Symlinking code."
        run "rm -f #{paths.current} && ln -nfs #{paths.active_release} #{paths.current} && find #{paths.current} -not -user #{config.user} -or -not -group #{config.group} -exec chown #{config.user}:#{config.group} {} +"
        @symlink_changed = true
      rescue Exception
        sudo "rm -f #{paths.current} && ln -nfs #{paths.previous_release(paths.active_release)} #{paths.current} && chown -R #{config.user}:#{config.group} #{paths.current}"
        @symlink_changed = false
        raise
      end

      def callback(what)
        @callbacks_reached ||= true
        if paths.deploy_hook(what).exist?
          shell.status "Running deploy hook: deploy/#{what}.rb"
          run Escape.shell_command(base_callback_command_for(what)) do |server, cmd|
            per_instance_args = []
            per_instance_args << '--current-roles' << server.roles.to_a.join(' ')
            per_instance_args << '--current-name'  << server.name.to_s if server.name
            per_instance_args << '--config'        << config.to_json
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
        ENV['GIT_SSH'] = ssh_executable.to_s
        @strategy ||= config.strategy_class.new(
          shell,
          :repository_cache => paths.repository_cache.to_s,
          :app              => config.app,
          :repo             => config[:repo],
          :ref              => config[:branch]
        )
      end

      def gemfile?
        paths.gemfile.exist?
      end

      def base_callback_command_for(what)
        cmd =  [serverside_bin, 'hook', what.to_s]
        cmd << '--app'              << config.app
        cmd << '--environment-name' << config.environment_name
        cmd << '--account-name'     << config.account_name
        cmd << '--release-path'     << paths.active_release.to_s
        cmd << '--framework-env'    << config.framework_env.to_s
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
        elsif maintenance.up?
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

      def maintenance
        @maintenance ||= Maintenance.new(servers, config, shell)
      end

      def with_failed_release_cleanup
        yield
      rescue Exception
        shell.status "Release #{paths.active_release} failed, saving release to #{paths.releases_failed}."
        sudo "mv #{paths.active_release} #{paths.releases_failed}"
        clean_release_directory(paths.releases_failed)
        raise
      end

      def bundler_config
        version = LockfileParser.default_version
        options = [
          "--gemfile #{paths.gemfile}",
          "--path #{paths.bundled_gems}",
          "--binstubs #{paths.binstubs}",
          "--without #{config.bundle_without}"
        ]

        if lockfile
          version = lockfile.bundler_version
          options.unshift('--deployment') # deployment mode is not supported without a Gemfile.lock
        end

        return [version, options.join(' ')]
      end

      def lockfile
        lockfile_path = paths.gemfile_lock
        if lockfile_path.exist?
          @lockfile_parser ||= LockfileParser.new(lockfile_path.read)
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
          run  "#{clean_environment} && cd #{paths.active_release} && ruby -S bundle _#{bundler_version}_ install #{install_switches}"

          write_system_version
        end
      end

      def clean_bundle_on_system_version_change
        # diff exits with 0 for same and 1/2 for different/file not found.
        check_ruby   = "#{config.ruby_version_command} | diff - #{paths.ruby_version} >/dev/null 2>&1"
        check_system = "#{config.system_version_command} | diff - #{paths.system_version} >/dev/null 2>&1"
        say_cleaning = "echo 'New deploy or system version change detected, cleaning bundled gems.'"
        clean_bundle = "rm -Rf #{paths.bundled_gems}"

        run "#{check_ruby} && #{check_system} || (#{say_cleaning} && #{clean_bundle})"
      end

      def write_system_version
        store_ruby_version   = "#{config.ruby_version_command} > #{paths.ruby_version}"
        store_system_version = "#{config.system_version_command} > #{paths.system_version}"

        run "mkdir -p #{paths.bundled_gems} && #{store_ruby_version} && #{store_system_version}"
      end

      def check_node_npm
        if paths.package_json.exist?
          shell.info "~> package.json detected, installing npm packages"
          run "cd #{paths.active_release} && npm install"
        end
      end
    end   # DeployBase

    class Deploy < DeployBase
    end
  end
end
