require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    class DeployHook
      def initialize(config, shell, hook_name)
        @config, @shell, @hook_name = config, shell, hook_name
      end

      def hook_path
        "#{@config.release_path}/deploy/#{@hook_name}.rb"
      end

      def callback_context
        @context ||= CallbackContext.new(@config, @shell, hook_path)
      end

      def call
        if File.exist?(hook_path)
          Dir.chdir(@config.release_path) do
            if desc = syntax_error(hook_path)
              hook_name = File.basename(hook_path)
              abort "*** [Error] Invalid Ruby syntax in hook: #{hook_name} ***\n*** #{desc.chomp} ***"
            else
              eval_hook(IO.read(hook_path))
            end
          end
        end
      end

      def eval_hook(code)
        callback_context.instance_eval(code)
      rescue Exception => exception
        display_hook_error(exception, code, hook_path)
        raise exception
      end

      def display_hook_error(exception, code, hook_path)
        @shell.fatal <<-ERROR
Exception raised in deploy hook #{hook_path.inspect}.

#{exception.class}: #{exception.to_s}

Please fix this error before retrying.
        ERROR
      end

      def syntax_error(file)
        output = `ruby -c #{file} 2>&1`
        output unless output =~ /Syntax OK/
      end

      class CallbackContext
        include EY::Serverside::Shell::Helpers

        attr_reader :shell

        def initialize(config, shell, hook_path)
          @configuration = config
          @configuration.set_framework_envs
          @shell = shell
          @node = node
          @hook_path = hook_path
        end

        def config
          @configuration
        end

        def inspect
          "#<DeployHook::CallbackContext #{hook_path.inspect}>"
        end

        def method_missing(meth, *args, &blk)
          if @configuration.respond_to?(meth)
            @configuration.send(meth, *args, &blk)
          else
            super
          end
        end

        def respond_to?(*a)
          @configuration.respond_to?(*a) || super
        end

        def run(cmd)
          shell.logged_system(Escape.shell_command(["sh", "-l", "-c", cmd])).success?
        end

        def sudo(cmd)
          shell.logged_system(Escape.shell_command(["sudo", "sh", "-l", "-c", cmd])).success?
        end

        # convenience functions for running on certain instance types
        def on_app_master(&blk)                 on_roles(%w[solo app_master],          &blk) end
        def on_app_servers(&blk)                on_roles(%w[solo app_master app],      &blk) end
        def on_app_servers_and_utilities(&blk)  on_roles(%w[solo app_master app util], &blk) end

        def on_utilities(*names, &blk)
          names.flatten!
          on_roles(%w[util]) do
            blk.call if names.empty? || names.include?(current_name)
          end
        end

        private
        def on_roles(desired_roles)
          yield if desired_roles.any? { |role| current_roles.include?(role) }
        end

      end

    end
  end
end
