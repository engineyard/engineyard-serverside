require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    class Task
      attr_reader :servers, :config, :shell
      alias :c :config

      def initialize(servers, conf, shell)
        @servers = servers
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

      def run(cmd, &block)
        servers.roles(@roles).run(shell, cmd, &block)
      end

      def sudo(cmd, &block)
        servers.roles(@roles).sudo(shell, cmd, &block)
      end

    end
  end
end
