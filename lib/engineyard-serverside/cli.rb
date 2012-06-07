require 'thor'
require 'pathname'
require 'engineyard-serverside/deploy'
require 'engineyard-serverside/shell'
require 'engineyard-serverside/server'

module EY
  module Serverside
    class CLI < Thor

      method_option :migrate,         :type     => :string,
                                      :desc     => "Run migrations with this deploy",
                                      :aliases  => ["-m"]

      method_option :branch,          :type     => :string,
                                      :desc     => "Git ref to deploy, defaults to master. May be a branch, a tag, or a SHA",
                                      :aliases  => %w[-b --ref --tag]

      method_option :repo,            :type     => :string,
                                      :desc     => "Remote repo to deploy",
                                      :aliases  => ["-r"]

      method_option :app,             :type     => :string,
                                      :required => true,
                                      :desc     => "Application to deploy",
                                      :aliases  => ["-a"]

      method_option :environment_name,:type     => :string,
                                      :required => true,
                                      :desc     => "Environment name"

      method_option :account_name,    :type     => :string,
                                      :required => true,
                                      :desc     => "Account name"

      method_option :framework_env,   :type     => :string,
                                      :desc     => "Ruby web framework environment",
                                      :aliases  => ["-e"]

      method_option :config,          :type     => :string,
                                      :desc     => "Additional configuration"

      method_option :stack,           :type     => :string,
                                      :desc     => "Web stack (so we can restart it correctly)"

      method_option :instances,       :type     => :array,
                                      :desc     => "Hostnames of instances to deploy to, e.g. --instances localhost app1 app2"

      method_option :instance_roles,  :type     => :hash,
                                      :default  => {},
                                      :desc     => "Roles of instances, keyed on hostname, comma-separated. e.g. instance1:app_master,etc instance2:db,memcached ..."

      method_option :instance_names,  :type     => :hash,
                                      :default  => {},
                                      :desc     => "Instance names, keyed on hostname. e.g. instance1:name1 instance2:name2"

      method_option :verbose,         :type     => :boolean,
                                      :desc     => "Verbose output",
                                      :aliases  => ["-v"]

      desc "deploy", "Deploy code from /data/<app>"
      def deploy(default_task=:deploy)
        config, shell = init_and_propagate(options, default_task.to_s)
        EY::Serverside::Deploy.new(config, shell).send(default_task)
      end

      method_option :app,           :type     => :string,
                                    :required => true,
                                    :desc     => "Which application's hooks to run",
                                    :aliases  => ["-a"]

      method_option :environment_name, :type     => :string,
                                       :required => true,
                                       :desc     => "Environment name"

      method_option :account_name,  :type     => :string,
                                    :required => true,
                                    :desc     => "Account name"

      method_option :release_path,  :type     => :string,
                                    :desc     => "Value for #release_path in hooks (mostly for internal coordination)",
                                    :aliases  => ["-r"]

      method_option :current_roles, :type     => :array,
                                    :desc     => "Value for #current_roles in hooks"

      method_option :framework_env, :type     => :string,
                                    :required => true,
                                    :desc     => "Ruby web framework environment",
                                    :aliases  => ["-e"]

      method_option :config,        :type     => :string,
                                    :desc     => "Additional configuration"

      method_option :current_name,  :type     => :string,
                                    :desc     => "Value for #current_name in hooks"

      method_option :verbose,       :type     => :boolean,
                                    :desc     => "Verbose output",
                                    :aliases  => ["-v"]

      desc "hook [NAME]", "Run a particular deploy hook"
      def hook(hook_name)
        config, shell = init(options, "hook-#{hook_name}")
        EY::Serverside::DeployHook.new(config, shell).run(hook_name)
      end


      method_option :app,             :type     => :string,
                                      :required => true,
                                      :desc     => "Application to deploy",
                                      :aliases  => ["-a"]

      method_option :environment_name,:type     => :string,
                                      :required => true,
                                      :desc     => "Environment name"

      method_option :account_name,    :type     => :string,
                                      :required => true,
                                      :desc     => "Account name"

      method_option :framework_env,   :type     => :string,
                                      :required => true,
                                      :desc     => "Ruby web framework environment",
                                      :aliases  => ["-e"]

      method_option :stack,           :type     => :string,
                                      :desc     => "Web stack (so we can restart it correctly)"

      method_option :instances,       :type     => :array,
                                      :desc     => "Hostnames of instances to deploy to, e.g. --instances localhost app1 app2"

      method_option :instance_roles,  :type     => :hash,
                                      :default  => {},
                                      :desc     => "Roles of instances, keyed on hostname, comma-separated. e.g. instance1:app_master,etc instance2:db,memcached ..."

      method_option :instance_names,  :type     => :hash,
                                      :default  => {},
                                      :desc     => "Instance names, keyed on hostname. e.g. instance1:name1 instance2:name2"

      method_option :verbose,         :type     => :boolean,
                                      :desc     => "Verbose output",
                                      :aliases  => ["-v"]
      desc "integrate", "Integrate other instances into this cluster"
      def integrate

        app_dir = Pathname.new "/data/#{options[:app]}"
        current_app_dir = app_dir + "current"

        # so that we deploy to the same place there that we have here
        integrate_options = options.dup
        integrate_options[:release_path] = current_app_dir.realpath.to_s

        # we have to deploy the same SHA there as here
        integrate_options[:branch] = (current_app_dir + 'REVISION').read.strip

        config, shell = init_and_propagate(integrate_options, 'integrate')

        EY::Serverside::Server.all.each do |server|
          shell.logged_system server.sync_directory_command(app_dir)
          # we're just about to recreate this, so it has to be gone
          # first. otherwise, non-idempotent deploy hooks could screw
          # things up, and since we don't control deploy hooks, we must
          # assume the worst.
          run_on_server(server,"rm -rf #{current_app_dir}")
        end

        # deploy local-ref to other instances into /data/$app/local-current
        EY::Serverside::Deploy.new(config, shell).cached_deploy
      end

      method_option :app,             :type     => :string,
                                      :required => true,
                                      :desc     => "Application to deploy",
                                      :aliases  => ["-a"]

      method_option :environment_name,:type     => :string,
                                      :required => true,
                                      :desc     => "Environment name"

      method_option :account_name,    :type     => :string,
                                      :required => true,
                                      :desc     => "Account name"

      method_option :stack,           :type     => :string,
                                      :desc     => "Web stack (so we can restart it correctly)"

      method_option :instances,       :type     => :array,
                                      :desc     => "Hostnames of instances to deploy to, e.g. --instances localhost app1 app2"

      method_option :instance_roles,  :type     => :hash,
                                      :default  => {},
                                      :desc     => "Roles of instances, keyed on hostname, comma-separated. e.g. instance1:app_master,etc instance2:db,memcached ..."

      method_option :instance_names,  :type     => :hash,
                                      :default  => {},
                                      :desc     => "Instance names, keyed on hostname. e.g. instance1:name1 instance2:name2"

      method_option :verbose,         :type     => :boolean,
                                      :desc     => "Verbose output",
                                      :aliases  => ["-v"]
      desc "restart", "Restart app servers, conditionally enabling maintenance page"
      def restart
        config, shell = init_and_propagate(options, 'restart')

        EY::Serverside::Deploy.new(config, shell).restart_with_maintenance_page
      end

      desc "install_bundler [VERSION]", "Make sure VERSION of bundler is installed (in system ruby)"
      def install_bundler(version)
        egrep_escaped_version = version.gsub(/\./, '\.')
        # the grep "bundler " is so that gems like bundler08 don't get
        # their versions considered too
        #
        # the [,$] is to stop us from looking for e.g. 0.9.2, seeing
        # 0.9.22, and mistakenly thinking 0.9.2 is there
        has_bundler_cmd = "gem list bundler | grep \"bundler \" | egrep -q '#{egrep_escaped_version}[,)]'"

        unless system(has_bundler_cmd)
          system("gem install bundler -q --no-rdoc --no-ri -v '#{version}'")
        end
      end

      private

      # Put the same engineyard-serverside on all the servers (Used to be public but is unused as an actual CLI command now)
      def propagate(shell)
        config          = EY::Serverside::Deploy::Configuration.new
        gem_filename    = "engineyard-serverside-#{EY::Serverside::VERSION}.gem"
        local_gem_file  = File.join(Gem.dir, 'cache', gem_filename)
        remote_gem_file = File.join(Dir.tmpdir, gem_filename)
        gem_binary      = File.join(Gem.default_bindir, 'gem')

        servers = EY::Serverside::Server.all.find_all { |server| !server.local? }

        shell.status "Propagating engineyard-serverside #{EY::Serverside::VERSION} to #{servers.size} server#{servers.size == 1 ? '' : 's' }."

        commands = servers.map do |server|
          shell.debug "Building propagate commands for #{server.hostname}"

          egrep_escaped_version = EY::Serverside::VERSION.gsub(/\./, '\.')
          # the [,)] is to stop us from looking for e.g. 0.5.1, seeing
          # 0.5.11, and mistakenly thinking 0.5.1 is there
          has_gem_cmd = "#{gem_binary} list engineyard-serverside | grep \"engineyard-serverside\" | egrep -q '#{egrep_escaped_version}[,)]'"

          proc do
            exists = shell.logged_system(server.command_on_server('sh -l -c', has_gem_cmd))
            if exists.success?
              exists # Future expects logged system result object
            else # doesn't have this exact version
              shell.status "Installing engineyard-serverside on #{server.hostname}"

              shell.logged_system(Escape.shell_command([
                'scp', '-i', "#{ENV['HOME']}/.ssh/internal",
                "-o", "StrictHostKeyChecking=no",
                local_gem_file,
               "#{config.user}@#{server.hostname}:#{remote_gem_file}",
              ]))
              install_gem_cmd = "#{gem_binary} install --no-rdoc --no-ri '#{remote_gem_file}'"
              shell.logged_system(server.command_on_server('sudo sh -l -c', install_gem_cmd))
            end
          end
        end

        futures = EY::Serverside::Future.call(commands)
        unless EY::Serverside::Future.success?(futures)
          failures = futures.select {|f| f.error? }.map {|f| f.inspect}.join("\n")
          raise EY::Serverside::RemoteFailure.new(failures)
        end
      end

      def init_and_propagate(*args)
        config, shell = init(*args)
        load_servers(config)
        propagate(shell)
        [config, shell]
      end

      def init(options, action)
        config = EY::Serverside::Deploy::Configuration.new(options)
        shell  = EY::Serverside::Shell.new(:verbose  => config.verbose, :log_path => File.join(ENV['HOME'], "#{config.app}-#{action}.log"))
        shell.debug "Initializing engineyard-serverside #{EY::Serverside::VERSION}."
        [config, shell]
      end

      def run_on_server(server, command)
        shell.logged_system(server.command_on_server('sh -l -c', command))
      end

      def load_servers(config)
        EY::Serverside::Server.load_all_from_array(assemble_instance_hashes(config))
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
