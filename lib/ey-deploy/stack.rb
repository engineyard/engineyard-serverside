class EY::Stack
  @@stack_map ||= {}
  class << self
    def register(infrastructure, stack_name)
      @@stack_map[infrastructure.to_s + '/' + stack_name.to_s] = self
    end

    def use(infrastructure, stack_name)
      if klass = @@stack_map[infrastructure.to_s + '/' + stack_name.to_s]
        klass.new
      else
        stack_name#raise("Stack not found #{infrastructure}/#{stack_name}")
      end
    end

    def roles_for(method, *args)
      @method_role_map ||= {}
      if args.empty?
        @method_role_map[method] || []
      else
        @method_role_map[method] = args.flatten
      end
    end

    def task_overrides(&block)
      @task_overrides ||= Module.new
      if block
        @task_overrides.module_eval &block
      else
        @task_overrides
      end
    end

    def inherited(sub)
      %w( @task_overrides @method_role_map ).each do |ivar|
        sub.instance_variable_set(ivar, instance_variable_get(ivar))
      end
    end
  end

  def roles_for(method)
    self.class.roles_for(method)
  end

  def task_overrides
    self.class.task_overrides
  end

  def uses_maintenance_page?
    false
  end

  task_overrides do
    def do_restart
      raise "#{self.class} failed to implement do_restart command"
    end
  end
end

require File.join(File.dirname(__FILE__), 'stack/app_cloud')
