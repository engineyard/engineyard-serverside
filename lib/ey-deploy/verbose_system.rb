module EY
  module VerboseSystem
    def self.instance_id
      @instance_id ||= `curl http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null`
    end

    def system(cmd)
      puts "::   #{EY::VerboseSystem.instance_id} running #{cmd}"
      super
    end
  end
end
