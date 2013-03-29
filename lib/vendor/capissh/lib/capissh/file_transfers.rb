require 'capissh/transfer'

module Capissh
  class FileTransfers
    attr_reader :configuration, :logger

    def initialize(configuration, logger)
      @configuration = configuration
      @logger = logger
    end

    # Store the given data at the given location on all servers targetted
    # by the current task. If <tt>:mode</tt> is specified it is used to
    # set the mode on the file.
    def put(servers, data, path, options={})
      upload(servers, StringIO.new(data), path, options)
    end

    # Get file remote_path from FIRST server targeted by
    # the current task and transfer it to local machine as path.
    #
    # Pass only one server, or the first of the set of servers will be used.
    #
    # get server, "#{deploy_to}/current/log/production.log", "log/production.log.web"
    def get(servers, remote_path, path, options={}, &block)
      download(Array(servers).slice(0,1), remote_path, path, options, &block)
    end

    def upload(servers, from, to, options={}, &block)
      opts = options.dup
      mode = opts.delete(:mode)
      transfer(servers, :up, from, to, opts, &block)
      if mode
        mode = mode.is_a?(Numeric) ? mode.to_s(8) : mode.to_s
        configuration.run servers, "chmod #{mode} #{to}", opts
      end
    end

    def download(servers, from, to, options={}, &block)
      transfer(servers, :down, from, to, options, &block)
    end

    def transfer(servers, direction, from, to, options={}, &block)
      transfer = Transfer.new(direction, from, to, options.merge(:logger => logger), &block)
      logger.info transfer.intent
      configuration.execute_on_servers(servers, options) do |sessions|
        transfer.call(sessions)
      end
    end

  end
end
