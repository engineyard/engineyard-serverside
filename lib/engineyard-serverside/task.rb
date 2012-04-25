require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    class Task
      include EY::Serverside::Shell::Helpers

      attr_reader :config, :shell
      alias :c :config

      def initialize(conf, shell = nil)
        @config = conf
        @shell = shell
        @roles = :all
      end

      def require_custom_tasks
        deploy_file = ["config/eydeploy.rb", "eydeploy.rb"].map do |short_file|
          File.join(c.repository_cache, short_file)
        end.detect do |file|
          File.exist?(file)
        end

        if deploy_file
          shell.status "Loading deployment task overrides from #{deploy_file}"
          instance_eval(File.read(deploy_file))
          true
        else
          false
        end
      end

      def load_ey_yml
        ey_yml = ["config/ey.yml", "ey.yml"].map do |short_file|
          File.join(c.repository_cache, short_file)
        end.detect do |file|
          File.exist?(file)
        end

        if ey_yml
          shell.status "Loading deploy configuration in #{ey_yml}"
          data = YAML.load_file(ey_yml)
          config.load_ey_yml_data(data, shell)
        else
          false
        end
      rescue Exception
        shell.error "Error loading YAML in #{ey_yml}"
        raise
      end

      def roles(*task_roles)
        raise "Roles must be passed a block" unless block_given?

        begin
          @roles = task_roles
          yield
        ensure
          @roles = :all
        end
      end

      # Returns +true+ if the command is successful,
      # raises EY::Serverside::RemoteFailure with a list of failures
      # otherwise.
      def run(cmd, &blk)
        run_on_roles(shell_command(cmd), &blk)
      end

      def sudo(cmd, &blk)
        run_on_roles("sudo #{shell_command(cmd)}", &blk)
      end

      def shell_command(cmd)
        "sh -l -c #{Escape.shell_command [cmd]}"
      end

      private

      def run_on_roles(cmd, &block)
        servers = EY::Serverside::Server.from_roles(@roles)

        commands = servers.map do |server|
          exec_cmd = server.command_on_server(cmd, &block)
          proc { shell.logged_system(exec_cmd) }
        end

        futures = EY::Serverside::Future.call(commands)

        unless EY::Serverside::Future.success?(futures)
          failures = futures.select {|f| f.error? }.map {|f| f.inspect}.join("\n")
          raise EY::Serverside::RemoteFailure.new(failures)
        end
      end
    end
  end
end
