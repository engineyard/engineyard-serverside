module EY
  module Serverside
    class Task

      attr_reader :config
      alias :c :config

      def initialize(conf)
        @config = conf
        @roles = :all
      end

      def require_custom_tasks
        deploy_file = ["config/eydeploy.rb", "eydeploy.rb"].map do |short_file|
          File.join(c.repository_cache, short_file)
        end.detect do |file|
          File.exist?(file)
        end

        if deploy_file
          puts "~> Loading deployment task overrides from #{deploy_file}"
          instance_eval(File.read(deploy_file))
          true
        else
          false
        end
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

      def run(cmd, &blk)
        run_on_roles(cmd, &blk)
      end

      def sudo(cmd, &blk)
        run_on_roles(cmd, %w[sudo sh -l -c], &blk)
      end

      private

      def run_on_roles(cmd, wrapper=%w[sh -l -c], &block)
        servers = EY::Serverside::Server.from_roles(@roles)
        futures = EY::Serverside::Future.call(servers, block_given?) do |server, exec_block|
          to_run = exec_block ? block.call(server, cmd.dup) : cmd
          server.run(Escape.shell_command(wrapper + [to_run]))
        end

        unless EY::Serverside::Future.success?(futures)
          failures = futures.select {|f| f.error? }.map {|f| f.inspect}.join("\n")
          raise EY::Serverside::RemoteFailure.new(failures)
        end
      end
    end
  end
end
