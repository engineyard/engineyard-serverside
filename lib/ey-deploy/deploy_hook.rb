require 'ey-deploy/verbose_system'

module EY
  class DeployHook < Task
    include VerboseSystem

    def initialize(options)
      super(EY::Deploy::Configuration.new(options))
    end

    def callback_context
      @context ||= CallbackContext.new(self, config)
    end

    def run(hook)
      if File.exist?("#{c.latest_release}/deploy/#{hook}.rb")
        Dir.chdir(c.latest_release) do
          puts "~> running deploy hook: deploy/#{hook}.rb"
          callback_context.instance_eval(IO.read("#{c.latest_release}/deploy/#{hook}.rb"))
        end
      end
    end

    class CallbackContext
      def initialize(hook_runner, config)
        @hook_runner, @config = hook_runner, config
      end

      def method_missing(meth, *args, &blk)
        if @config.respond_to?(meth)
          @config.send(meth, *args, &blk)
        else
          super
        end
      end

      def respond_to?(meth)
        @config.respond_to?(meth) || super
      end

      def run(cmd)
        system(@hook_runner.prepare_run(cmd))
      end

      def sudo(cmd)
        system(@hook_runner.prepare_sudo(cmd))
      end
    end

  end
end

