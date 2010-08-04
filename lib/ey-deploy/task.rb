module EY
  class Task
    include Dataflow

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

    def run_on_roles(cmd, wrapper=%w[sh -l -c])
      results = EY::Server.from_roles(@roles).map do |server|
        to_run = block_given? ? yield(server, cmd.dup) : cmd
        need_later { server.run(Escape.shell_command(wrapper + [to_run])) }
      end
      barrier *results
      # MRI's truthiness check is an internal C thing that does not call
      # any methods... so Dataflow cannot proxy it & we must "x == true"
      # Rubinius, wherefore art thou!?
      results.all?{|x| x == true } || raise(EY::RemoteFailure)
    end
  end
end
