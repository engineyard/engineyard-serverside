require 'engineyard-serverside/shell/helpers'
require 'engineyard-serverside/deploy_hook/callback_context'
require 'engineyard-serverside/callbacks'
require 'rbconfig'

module EY
  module Serverside
    class DeployHook
      attr_reader :config, :shell, :hook_name

      def initialize(config, shell, hook_name)
        @config, @shell, @hook_name = config, shell, hook_name
      end

      def call
        hooks.execute
      end

      #def call
        #hooks.each do |hook|
          #Dir.chdir(config.paths.active_release.to_s) do
            #if desc = syntax_error(hook.path)
              #hook_name = hook.path.basename
              #abort "*** [Error] Invalid Ruby syntax in hook: #{hook_name} ***\n*** #{desc.chomp} ***"
            #else
              #eval_hook(hook.read, hook.path)
            #end
          #end
        #end
      #end

      def eval_hook(code, hook_path = nil)
        hook_path ||= config.paths.deploy_hook(hook_name)
        shell.info "Executing #{hook_path} ..."
        display_deprecation_warnings(code, hook_path)
        CallbackContext.
          new(config, shell, hook_path).
          instance_eval(code)
      rescue Exception => exception
        display_hook_error(exception, code, hook_path)
        raise exception
      end

      def display_deprecation_warnings(code, hook_path)
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

      private
      def hooks
        @hooks ||= Callbacks.
          load(config.paths).
          matching(hook_name.to_s)
      end

    end
  end
end
