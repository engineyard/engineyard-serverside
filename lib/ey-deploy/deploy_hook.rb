module EY
  class DeployHook < Task
    def initialize(options)
      super(EY::Deploy::Configuration.new(options))
    end

    def callback_context
      @context ||= CallbackContext.new(config)
    end

    def run(hook)
      hook_path = "#{c.release_path}/deploy/#{hook}.rb"
      if File.exist?(hook_path)
        Dir.chdir(c.release_path) do
          puts "~> running deploy hook: deploy/#{hook}.rb"
          if desc = syntax_error(hook_path)
            hook_name = File.basename(hook_path)
            abort "*** [Error] Invalid Ruby syntax in hook: #{hook_name} ***\n*** #{desc.chomp} ***"
          else
            callback_context.instance_eval(IO.read(hook_path))
          end
        end
      end
    end

    def syntax_error(file)
      valid = Kernel.system("ruby -c #{file} 2>/tmp/ey_invalid_deploy_hook | grep 'Syntax OK' --quiet")
      File.new("/tmp/ey_invalid_deploy_hook").gets unless valid
    end

    class CallbackContext
      def initialize(config)
        @configuration = config
        @node = node
      end

      def method_missing(meth, *args, &blk)
        if @configuration.respond_to?(meth)
          @configuration.send(meth, *args, &blk)
        else
          super
        end
      end

      def respond_to?(meth, include_private=false)
        @configuration.respond_to?(meth, include_private) || super
      end

      def run(cmd)
        system(Escape.shell_command(["sh", "-l", "-c", cmd]))
      end

      def sudo(cmd)
        system(Escape.shell_command(["sudo", "sh", "-l", "-c", cmd]))
      end

      # convenience functions for running on certain instance types
      def on_app_master(&blk)                 on_roles(%w[solo app_master],          &blk) end
      def on_app_servers(&blk)                on_roles(%w[solo app_master app],      &blk) end
      def on_db_master(&blk)                  on_roles(%w[solo db_master],           &blk) end
      def on_db_slaves(&blk)                  on_roles(%w[db_slave],                 &blk) end
      def on_db_servers(&blk)                 on_roles(%w[solo db_master db_slave],  &blk) end
      def on_app_servers_and_utilities(&blk)  on_roles(%w[solo app_master app util], &blk) end

      def on_utilities(*names, &blk)
        names.flatten!
        on_roles(%w[util]) do
          blk.call if names.empty? || names.include?(current_name)
        end
      end

      private
      def on_roles(desired_roles)
        yield if desired_roles.include?(current_role.to_s)
      end

    end

  end
end

