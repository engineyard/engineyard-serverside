# Inspired by capistrano, thanks Jamis!
require 'base64'
require 'multi_json'
require 'engineyard-serverside/rails_assets'
require 'engineyard-serverside/maintenance'
require 'engineyard-serverside/dependency_manager'
require 'engineyard-serverside/dependency_manager/legacy_helpers'

module EY
  module Serverside
    class DeployBase < Task
      include ::EY::Serverside::DependencyManager::LegacyHelpers

      # default task
      def deploy
        shell.status "Starting deploy at #{shell.start_time.asctime}"
        update_repository_cache
        cached_deploy
      end

      def cached_deploy
        shell.status "Deploying app from cached copy at #{Time.now.asctime}"
        load_ey_yml
        require_custom_tasks
        push_code

        shell.status "Starting full deploy"
        copy_repository_cache
        check_repository

        with_failed_release_cleanup do
          create_revision_file
          run_with_callbacks(:bundle)
          setup_services
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
        gc_repository_cache
        shell.status "Finished deploy at #{Time.now.asctime}"
      rescue Exception => e
        shell.status "Finished failing to deploy at #{Time.now.asctime}"
        shell.error "Exception during deploy: #{e.inspect}\n#{e.backtrace}"
        puts_deploy_failure
        raise
      end

      def update_repository_cache
        source.update_repository_cache
      end

      def gc_repository_cache
        source.gc_repository_cache
      end

      def create_revision_file_command
        source.create_revision_file_command(paths.active_revision)
      end

      def short_log_message(revision)
        source.short_log_message(revision)
      end

      def unchanged_diff_between_revisions?(previous_revision, active_revision, asset_dependencies)
        source.same?(previous_revision, active_revision, asset_dependencies)
      end

      def check_repository
        check_dependencies
      end

      def check_dependencies
        dependency_manager.check
      end

      def rails_application?
        dependency_manager.rails_version
      end

      def bundle
        install_dependencies
      end

      def install_dependencies
        dependency_manager.install
      end

      def restart_with_maintenance_page
        load_ey_yml
        require_custom_tasks
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
        servers.remote.run_for_each do |server|
          server.sync_directory_command(paths.repository_cache)
        end
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

      def ensure_git_ssh_wrapper
        ENV['GIT_SSH'] = ssh_executable.to_s
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
[ -x #{path} ] || cat > #{path} <<'SSH'
#!/bin/sh
unset SSH_AUTH_SOCK
ssh -o CheckHostIP=no -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o LogLevel=INFO -o IdentityFile=#{paths.deploy_key} -o IdentitiesOnly=yes $*
SSH
chmod 0700 #{path}
        SCRIPT
      end

      # task
      def cleanup_old_releases
        clean_release_directory(paths.releases)
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

      def abort_on_bad_paths_in_release_directory
        shell.substatus "Checking for disruptive files in #{paths.releases}"

        bad_paths = paths.all_releases.reject do |path|
          path.basename.to_s =~ /^[\d]+$/
        end

        if bad_paths.any?
          shell.fatal "Bad paths found in #{paths.releases}:\n\t#{bad_paths.join("\n\t")}\nStoring files in this directory will disrupt latest_release, diff detection, rollback, and possibly other features."
          raise
        end
      end


      # task
      def rollback
        if config.rollback_paths!
          begin
            rolled_back_release = paths.latest_release
            shell.status "Rolling back to previous release: #{short_log_message(config.active_revision)}"
            abort_on_bad_paths_in_release_directory
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
        run("mkdir -p #{paths.active_release} #{paths.shared_config} && rsync -aq #{exclusions} #{paths.repository_cache}/ #{paths.active_release}")

        shell.status "Ensuring proper ownership."
        ensure_ownership(paths.active_release)
      end

      def create_revision_file
        run create_revision_file_command
      end

      def setup_services
        shell.status "Setting up external services."
        previously_configured_services = config.configured_services

        begin
          sudo(config.services_check_command)
        rescue EY::Serverside::RemoteFailure
          shell.info "Could not setup services. Upgrade your environment to get services configuration."
          return
        end

        begin
          sudo(config.services_setup_command)
        rescue EY::Serverside::RemoteFailure => e
          if previously_configured_services
            shell.warning <<-WARNING
External services configuration not updated. Using previous version.
Deploy again if your services configuration appears incomplete or out of date.
#{e}
            WARNING
          end
        end

        if services = config.configured_services
          shell.status "Services configured: #{services.join(', ')}"
          dependency_manager.show_ey_config_instructions
        end
      end

      def setup_sqlite3_if_necessary
        if dependency_manager.uses_sqlite3?
          shell.status "Setting up SQLite3 Database for compatibility with application's chosen adapter"
          shell.warning "SQLite3 cannot persist across servers. Please upgrade to a supported database."

          shell.substatus "Create databases directory if needed"
          run "mkdir -p #{paths.shared}/databases"

          shell.substatus "Create SQLite database if needed"
          run "touch #{paths.shared}/databases/#{config.framework_env}.sqlite3"

          shell.substatus "Create config directory if needed"
          run "mkdir -p #{paths.active_release_config}"

          shell.substatus "Generating SQLite config"
          run <<-WRAP
cat > #{paths.shared_config}/database.sqlite3.yml<<'YML'
#{config.framework_env}:
  adapter: sqlite3
  database: #{paths.shared}/databases/#{config.framework_env}.sqlite3
  pool: 5
  timeout: 5000
YML
          WRAP

          shell.substatus "Symlink database.yml"
          run "ln -nfs #{paths.shared_config}/database.sqlite3.yml #{paths.active_release_config}/database.yml"
        end
      end

      def symlink_configs
        shell.status "Preparing shared resources for release."
        symlink_tasks.each do |what, cmd|
          shell.substatus what
          run(cmd)
        end
      end

      def symlink_tasks
        [
          ["Set group write permissions",           "chmod -R g+w #{paths.active_release}"],
          ["Remove symlinked shared directories",   "rm -rf #{paths.active_log} #{paths.public_system} #{paths.active_release}/tmp/pids"],
          ["Create tmp directory",                  "mkdir -p #{paths.active_release}/tmp"],
          ["Create public directory",               "mkdir -p #{paths.public}"],
          ["Create config directory",               "mkdir -p #{paths.active_release_config}"],
          ["Symlink shared log directory",          "ln -nfs #{paths.shared_log} #{paths.active_log}"],
          ["Symlink public system directory",       "ln -nfs #{paths.shared_system} #{paths.public_system}"],
          ["Symlink shared pids directory",         "ln -nfs #{paths.shared}/pids #{paths.active_release}/tmp/pids"],
          ["Symlink other shared config files",     "find #{paths.shared_config} -type f -not -name 'database.yml' -exec ln -s {} #{paths.active_release_config} \\;"],
          ["Symlink database.yml if needed",        "if [ -f \"#{paths.shared_config}/database.yml\" ]; then ln -nfs #{paths.shared_config}/database.yml #{paths.active_release_config}/database.yml; fi"],
          ["Symlink newrelic.yml if needed",        "if [ -f \"#{paths.shared_config}/newrelic.yml\" ]; then ln -nfs #{paths.shared_config}/newrelic.yml #{paths.active_release_config}/newrelic.yml; fi"],
          ["Symlink mongrel_cluster.yml if needed", "if [ -f \"#{paths.shared_config}/mongrel_cluster.yml\" ]; then ln -nfs #{paths.shared_config}/mongrel_cluster.yml #{paths.active_release_config}/mongrel_cluster.yml; fi"],
        ]
      end

      # task
      def symlink
        shell.status "Symlinking code."
        run move_symlink(paths.active_release, paths.current, "deploying")
        ensure_ownership(paths.current)
        @symlink_changed = true
      rescue Exception
        sudo move_symlink(paths.previous_release(paths.active_release), paths.current, "reverting")
        ensure_ownership(paths.current)
        @symlink_changed = false
        raise
      end

      def ensure_ownership(*targets)
        sudo "find #{targets.join(' ')} -not -user #{config.user} -or -not -group #{config.group} -exec chown #{config.user}:#{config.group} {} +"
      end

      # Move a symlink as atomically as we can.
      #
      # mv -T renames 'next' to 'current' instead of moving 'next' to current/next'
      # mv -T isn't available on OS X and maybe elsewhere, so fallback to rm && ln
      def move_symlink(source, link, name)
        next_link = link.dirname.join(name)
        mv_t  = "ln -nfs #{source} #{next_link} && mv -T #{next_link} #{link} >/dev/null 2>&1"
        rm_ln = "rm -rf #{next_link} #{link} && ln -nfs #{source} #{link}"
        "((#{mv_t}) || (#{rm_ln}))"
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

      # Use [] to access attributes instead of calling methods so
      # that we get nils instead of NoMethodError.
      #
      # Rollback doesn't know about the repository location (nor
      # should it need to), but it would like to use #short_log_message.
      def source
        ensure_git_ssh_wrapper
        @source ||= config.source(shell)
      end

      protected

      def base_callback_command_for(what)
        cmd =  [About.binary, 'hook', what.to_s]
        cmd << '--app'              << config.app
        cmd << '--environment-name' << config.environment_name
        cmd << '--account-name'     << config.account_name
        cmd << '--release-path'     << paths.active_release.to_s
        cmd << '--framework-env'    << config.framework_env.to_s
        cmd << '--verbose' if config.verbose
        cmd
      end

      # FIXME: Legacy method, warn and remove.
      def serverside_bin
        About.binary
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

      def with_failed_release_cleanup
        yield
      rescue Exception => e
        shell.status "Release #{paths.active_release} failed, saving release to #{paths.releases_failed}."
        run "mkdir -p #{paths.releases_failed}"
        ensure_ownership(paths.active_release, paths.releases_failed)
        run "mv #{paths.active_release} #{paths.releases_failed}"
        clean_release_directory(paths.releases_failed)
        raise e
      end

      def maintenance
        @maintenance ||= Maintenance.new(servers, config, shell)
      end

      def dependency_manager
        ensure_git_ssh_wrapper
        @dependency_manager ||= DependencyManager.new(servers, config, shell, self)
      end

      def compile_assets
        RailsAssets.detect_and_compile(config, shell, self)
      end
    end   # DeployBase

    class Deploy < DeployBase
    end
  end
end
