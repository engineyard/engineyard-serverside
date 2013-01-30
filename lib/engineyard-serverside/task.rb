require 'engineyard-serverside/shell/helpers'
require 'yaml'

module EY
  module Serverside
    class Task
      attr_reader :servers, :config, :shell

      def initialize(servers, config, shell)
        @servers = servers
        @config = config
        @shell = shell
        @roles = :all
      end

      def paths
        config.paths
      end

      def require_custom_tasks
        return unless config.eydeploy_rb?

        deploy_file = ["config/eydeploy.rb", "eydeploy.rb"].map do |short_file|
          paths.repository_cache.join(short_file)
        end.detect do |file|
          file.exist?
        end

        if deploy_file
          shell.notice <<-NOTICE
NOTICE: Loading deployment task overrides from #{deploy_file}
Please consider:
* eydeploy.rb files can drastically alter the behavior of deployments.
* Internal deployment code may change under this file without warning.
          NOTICE
          begin
            instance_eval(deploy_file.read)
          rescue Exception => e
            shell.fatal ["Exception while loading #{deploy_file}", e.to_s, e.backtrace].join("\n")
            raise
          end
        end
      end

      def load_ey_yml
        ey_yml = ["config/ey.yml", "ey.yml"].map do |short_file|
          paths.repository_cache.join(short_file)
        end.detect do |file|
          file.exist?
        end

        if ey_yml
          shell.status "Loading deploy configuration in #{ey_yml}"
          data = YAML.load_file(ey_yml.to_s)
          config.load_ey_yml_data(data, shell)
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

      def run(cmd, &block)
        servers.roles(@roles).run(session, cmd, &block)
      end

      def sudo(cmd, &block)
        servers.roles(@roles).sudo(session, cmd, &block)
      end

      def session
        @session ||= Capissh.new(
          :level => 3,
          :pre_exec_callback => lambda { |command, server|
            command.gsub(/\$EY_SS_ROLES\$/, Escape.shell_command([server.server.roles.to_a.join(' ')]))
            command.gsub(/\$EY_SS_NAME\$/, Escape.shell_command([server.server.name.to_s]))
            shell.cmd_show(command)
            command
          }
        )
      end

    end
  end
end
