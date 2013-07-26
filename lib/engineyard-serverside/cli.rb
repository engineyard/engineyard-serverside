require 'thor'
require 'pathname'
require 'engineyard-serverside/about'
require 'engineyard-serverside/deploy'
require 'engineyard-serverside/shell'
require 'engineyard-serverside/servers'
require 'engineyard-serverside/cli_helpers'

module EY
  module Serverside
    class CLI < Thor

      extend CLIHelpers

      method_option :migrate,         :type     => :string,
                                      :desc     => "Run migrations with this deploy",
                                      :aliases  => ["-m"]

      method_option :branch,          :type     => :string,
                                      :desc     => "Git ref to deploy, defaults to master. May be a branch, a tag, or a SHA",
                                      :aliases  => %w[-b --ref --tag]

      method_option :repo,            :type     => :string,
                                      :desc     => "Remote repo to deploy",
                                      :aliases  => ["-r"]

      method_option :uri,             :type     => :string,
                                      :desc     => "Remote URI for archive to download",
                                      :aliases  => ["-u"]
      account_app_env_options
      config_option
      framework_env_option
      instances_options
      stack_option
      verbose_option

      desc "deploy", "Deploy code to /data/<app>"
      def deploy(default_task=:deploy)
        init_and_propagate(options, default_task.to_s) do |servers, config, shell|
          EY::Serverside::Deploy.new(servers, config, shell).send(default_task)
        end
      end

      account_app_env_options
      config_option
      instances_options
      verbose_option
      desc "enable_maintenance", "Enable maintenance page (disables web access)"
      def enable_maintenance
        init_and_propagate(options, 'enable_maintenance') do |servers, config, shell|
          EY::Serverside::Maintenance.new(servers, config, shell).manually_enable
        end
      end

      account_app_env_options
      config_option
      instances_options
      verbose_option
      desc "disable_maintenance", "Disable maintenance page (enables web access)"
      def disable_maintenance
        init_and_propagate(options, 'disable_maintenance') do |servers, config, shell|
          EY::Serverside::Maintenance.new(servers, config, shell).manually_disable
        end
      end

      method_option :release_path,  :type     => :string,
                                    :desc     => "Value for #release_path in hooks (mostly for internal coordination)",
                                    :aliases  => ["-r"]

      method_option :current_roles, :type     => :array,
                                    :desc     => "Value for #current_roles in hooks"

      method_option :current_name,  :type     => :string,
                                    :desc     => "Value for #current_name in hooks"
      account_app_env_options
      config_option
      framework_env_option
      verbose_option
      desc "hook [NAME]", "Run a particular deploy hook"
      def hook(hook_name)
        init(options, "hook-#{hook_name}") do |config, shell|
          EY::Serverside::DeployHook.new(config, shell, hook_name).call
        end
      end

      account_app_env_options
      config_option
      framework_env_option
      instances_options
      stack_option
      verbose_option
      desc "integrate", "Integrate other instances into this cluster"
      def integrate
        app_dir = Pathname.new "/data/#{options[:app]}"
        current_app_dir = app_dir.join("current")

        # so that we deploy to the same place there that we have here
        integrate_options = options.dup
        integrate_options[:release_path] = current_app_dir.realpath.to_s

        # we have to deploy the same SHA there as here
        integrate_options[:branch] = current_app_dir.join('REVISION').read.strip

        init_and_propagate(integrate_options, 'integrate') do |servers, config, shell|

          # We have to rsync the entire app dir, so we need all the permissions to be correct!
          chown_command = "find #{app_dir} -not -user #{config.user} -or -not -group #{config.group} -exec chown #{config.user}:#{config.group} {} +"
          shell.logged_system("sudo sh -l -c '#{chown_command}'", servers.detect {|s| s.local?})

          servers.run_for_each! do |server|
            sync  = server.sync_directory_command(app_dir)
            clean = server.command_on_server('sh -l -c', "rm -rf #{current_app_dir}")
            "(#{sync}) && (#{clean})"
          end

          # deploy local-ref to other instances into /data/$app/local-current
          EY::Serverside::Deploy.new(servers, config, shell).cached_deploy
        end
      end

      account_app_env_options
      instances_options
      stack_option
      verbose_option
      desc "restart", "Restart app servers, conditionally enabling maintenance page"
      def restart
        init_and_propagate(options, 'restart') do |servers, config, shell|
          EY::Serverside::Deploy.new(servers, config, shell).restart_with_maintenance_page
        end
      end

      private

      def init_and_propagate(*args)
        init(*args) do |config, shell|
          servers = load_servers(config, shell)
          propagate(servers, shell)
          yield servers, config, shell
        end
      end

      def init(options, action)
        config = EY::Serverside::Deploy::Configuration.new(options)
        shell  = EY::Serverside::Shell.new(
          :verbose  => config.verbose,
          :log_path => File.join(ENV['HOME'], "#{config.app}-#{action}.log")
        )
        shell.debug "Initializing #{About.name_with_version}."
        begin
          yield config, shell
        rescue EY::Serverside::RemoteFailure => e
          shell.exception "#{e.message}"
          raise
        rescue Exception => e
          shell.exception "#{e.backtrace[0]}: #{e.message} (#{e.class})"
          raise
        end
      end

      def propagate(servers, shell)
        shell.status "Verifying and propagating #{About.name_with_version} to all servers."

        gem_binary = File.join(Gem.default_bindir, 'gem')
        remote_gem_file = File.join(Dir.tmpdir, About.gem_filename)

        # the [,)] is to stop us from looking for e.g. 0.5.1, seeing
        # 0.5.11, and mistakenly thinking 0.5.1 is there
        check_command = %{#{gem_binary} list #{About.gem_name} | grep "#{About.gem_name}" | egrep -q "#{About.version.gsub(/\./, '\.')}[,)]"}
        install_command = "#{gem_binary} install --no-rdoc --no-ri '#{remote_gem_file}'"

        servers.remote.run_for_each! do |server|
          check   = server.command_on_server('sh -l -c', check_command)
          scp     = server.scp_command(About.gem_file, remote_gem_file)
          install = server.command_on_server('sudo sh -l -c', install_command)

          "(#{check}) || ((#{scp}) && (#{install}))"
        end
      end

      def load_servers(config, shell)
        EY::Serverside::Servers.from_hashes(assemble_instance_hashes(config), shell)
      end

      def assemble_instance_hashes(config)
        options[:instances].collect { |hostname|
          { :hostname => hostname,
            :roles => options[:instance_roles][hostname].to_s.split(','),
            :name => options[:instance_names][hostname],
            :user => config.user,
          }
        }
      end

    end
  end
end
