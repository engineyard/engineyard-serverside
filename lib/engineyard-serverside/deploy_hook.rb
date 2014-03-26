require 'engineyard-serverside/shell/helpers'
require 'rbconfig'

module EY
  module Serverside
    class DeployHook
      attr_reader :config, :shell, :hook_name

      def initialize(config, shell, hook_name)
        @config, @shell, @hook_name = config, shell, hook_name
      end

      def hook_path
        config.paths.deploy_hook(hook_name)
      end

      def callback_context
        @context ||= CallbackContext.new(config, shell, hook_path)
      end

      def call
        if hook_path.exist?
          Dir.chdir(config.paths.active_release.to_s) do
            if desc = syntax_error(hook_path)
              hook_name = hook_path.basename
              abort "*** [Error] Invalid Ruby syntax in hook: #{hook_name} ***\n*** #{desc.chomp} ***"
            else
              eval_hook(hook_path.read)
            end
          end
        end
      end

      def eval_hook(code)
        display_deprecation_warnings(code)
        callback_context.instance_eval(code)
      rescue Exception => exception
        display_hook_error(exception, code, hook_path)
        raise exception
      end

      def display_deprecation_warnings(code)
        if code =~ /@configuration/
          shell.warning("Use of `@configuration` in deploy hooks is deprecated.\nPlease use `config`, which provides access to the same object.\n\tin #{hook_path}")
        end
        if code =~ /@node/
          shell.warning("Use of `@node` in deploy hooks is deprecated.\nPlease use `config.node`, which provides access to the same object.\n\tin #{hook_path}")
        end
      end

      def display_hook_error(exception, code, hook_path)
        shell.fatal <<-ERROR
Exception raised in deploy hook #{hook_path}.

#{exception.class}: #{exception.to_s}

Please fix this error before retrying.
        ERROR
      end

      # Ideally we'd use RbConfig.ruby, but that doesn't work on 1.8.7.
      def ruby_bin
        File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
      end

      def syntax_error(file)
        output = `#{ruby_bin} -c #{file} 2>&1`
        output unless output =~ /Syntax OK/
      end

      class CallbackContext
        include EY::Serverside::Shell::Helpers

        attr_reader :shell, :hook_path

        def initialize(config, shell, hook_path)
          @configuration = config
          @configuration.set_framework_envs
          @shell = shell
          @node = config.node
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
            shell.warning "Use of `#{meth}` (via method_missing) is deprecated in favor of `config.#{meth}` for improved error messages and compatibility.\n\tin #{hook_path}"
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

        def run!(cmd)
          run(cmd) or raise("run!: Command failed. #{cmd}")
        end

        def sudo(cmd)
          shell.logged_system(Escape.shell_command(["sudo", "sh", "-l", "-c", cmd])).success?
        end

        def sudo!(cmd)
          sudo(cmd) or raise("sudo!: Command failed. #{cmd}")
        end

        # convenience functions for running on certain instance types
        def on_app_master(&blk)                 on_roles(%w[solo app_master],          &blk) end
        def on_app_servers(&blk)                on_roles(%w[solo app_master app],      &blk) end
        def on_app_servers_and_utilities(&blk)  on_roles(%w[solo app_master app util], &blk) end

        def on_utilities(*names, &blk)
          names.flatten!
          on_roles(%w[util]) do
            blk.call if names.empty? || names.include?(config.current_name)
          end
        end

        private
        def on_roles(desired_roles)
          yield if desired_roles.any? { |role| config.current_roles.include?(role) }
        end

      end

    end
  end
end
