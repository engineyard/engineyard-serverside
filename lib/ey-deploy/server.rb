module EY
  class Server < Struct.new(:hostname, :repository_cache)
    attr_writer :default_task

    def push_code
      run "mkdir -p #{repository_cache}"
      puts `rsync -aq -e "#{ssh_command}" #{repository_cache}/ #{hostname}:#{repository_cache}`
    end

    def run(command)
      puts `#{ssh_command} #{hostname} #{command}`
    end

    def ssh_command
      "ssh -i /root/.ssh/internal"
    end

    def default_task
      @default_task || "deploy"
    end
  end
end