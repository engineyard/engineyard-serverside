module Capissh
  class ServerDefinition
    include Comparable

    # Wraps a string in a ServerDefinition, if it isn't already.
    def self.wrap_server(item, options)
      item.is_a?(ServerDefinition) ? item : ServerDefinition.new(item, options)
    end

    # Turns a list, or something resembling a list, into a properly-formatted
    # ServerDefinition list. Keep an eye on this one -- it's entirely too
    # magical for its own good. In particular, if ServerDefinition ever inherits
    # from Array, this will break.
    def self.wrap_list(*list)
      options = list.last.is_a?(Hash) ? list.pop : {}
      if list.length == 1
        if list.first.nil?
          return []
        elsif list.first.is_a?(Array)
          list = list.first
        end
      end
      options.merge! list.pop if list.last.is_a?(Hash)
      list.map do |item|
        self.wrap_server item, options
      end
    end

    # The default user name to use when a user name is not explicitly provided
    def self.default_user
      ENV['USER'] || ENV['USERNAME'] || "not-specified"
    end

    attr_reader :user, :host, :port, :options, :server

    # Initialize a ServerDefinition with a string or object that describes the
    # authority URI part, "user@host:port", for connecting with SSH.
    #
    # Any object that responds to the following methods, in order of priority,
    # can be used in a ServerDefinition:
    #
    # 1. #host, #user (optional), and #port (optional, default: 22)
    # 2. #authority - responding with something like "[user@]host[:port]"
    # 3. #to_s      - responding with something like "[user@]host[:port]"
    #
    # If options are passed for the second argument, certain keys will be used:
    #
    # * :user - sets the user if one was not given in the authority
    # * :port - sets the port if one was not given in the authority
    # * :ssh_options - used for connecting with Net::SSH
    def initialize(server, options={})
      @server = server

      if @server.respond_to?(:host)
        @host = @server.host
        @port = @server.port if @server.respond_to?(:port)
        @user = @server.user if @server.respond_to?(:user)
      else
        if @server.respond_to?(:authority)
          string = @server.authority
        elsif @server.respond_to?(:to_s)
          string = @server.to_s
        else
          raise ArgumentError, "Invalid server for ServerDefinition: #{@server.inspect}. Must respond to #host, #authority, or #to_s"
        end
        @user, @host, @port = string.match(/^(?:([^;,:=]+)@|)(.*?)(?::(\d+)|)$/)[1,3]
      end

      @options = options.dup
      user_opt, port_opt = @options.delete(:user), @options.delete(:port)

      @user ||= user_opt
      @port ||= port_opt

      @port = @port.to_i if @port
    end

    def <=>(server)
      [host, port, user] <=> [server.host, server.port, server.user]
    end

    # Redefined, so that Array#uniq will work to remove duplicate server
    # definitions, based solely on their host names.
    def eql?(server)
      host == server.host &&
        user == server.user &&
        port == server.port
    end

    alias :== :eql?

    # Redefined, so that Array#uniq will work to remove duplicate server
    # definitions, based on their connection information.
    def hash
      @hash ||= [host, user, port].hash
    end

    def to_s
      @to_s ||= begin
        s = host
        s = "#{user}@#{s}" if user
        s = "#{s}:#{port}" if port && port != 22
        s
      end
    end
  end
end
