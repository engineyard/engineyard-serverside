module EY
  class Server < Struct.new(:hostname, :role)
    def self.repository_cache=(repo_cache)
      @@repository_cache = repo_cache
    end

    def repository_cache
      @@repository_cache
    end

    attr_writer :default_task

    def self.all
      @servers ||= (app_slaves << db_master << db_slaves << utils << current).flatten.compact.uniq
    end

    def self.current
      @current ||= new("localhost", EY.node["instance_role"].to_sym)
    end

    def self.app_slaves
      @app_slaves ||= Array(EY.node["members"]).map do |slave|
        new(slave, :app_slave)
      end
    end

    def self.db_master
      return @db_master if @db_master
      if EY.node["instance_role"] == "solo"
        @db_master = nil
      else
        @db_master = EY.node["db_host"] && new(EY.node["db_host"], :db_master)
      end
    end

    def self.db_slaves
      EY.node["db_slaves"].each do |slave|
        new(slave, :db_slave)
      end
    end

    def self.utils
      EY.node["utility_instances"].map{|util| util["hostname"]}.each do |server|
        new(server, :util)
      end
    end

    # For the purpose of making uniq ignore roles
    def eql?(other); hostname == other.hostname; end
    def hash; hostname.hash; end
    def ==(other); eql?(other); end

    def local?
      [:master, :solo].include?(role)
    end

    def push_code
      return if local?
      run "mkdir -p #{repository_cache}"
      system(%|rsync -aq -e "#{ssh_command}" #{repository_cache}/ #{hostname}:#{repository_cache}|)
    end

    def run(command)
      if local?
        puts "Running command locally"
        system("#{command.gsub(/\\"/, '"')}")
      else
        puts "Running command remotely"
        system("#{ssh_command} #{hostname} #{command}")
      end
    end

    def ssh_command
      "ssh -i /root/.ssh/internal"
    end

    def default_task
      if [:master, :solo, :app_slave].include?(role)
        "deploy"
      else
        "symlink_only"
      end
    end
  end
end