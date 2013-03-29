require 'enumerator'
require 'net/ssh/gateway'
require 'capissh/ssh'
require 'capissh/errors'
require 'capissh/server_definition'
require 'capissh/logger'
require 'capissh/sessions'

module Capissh
  class ConnectionManager
    class DefaultConnectionFactory
      def initialize(options)
        @options = options
      end

      def connect_to(server)
        SSH.connect(server, @options)
      end
    end

    class GatewayConnectionFactory
      def initialize(gateway, options)
        @options = options
        Thread.abort_on_exception = true
        @gateways = {}
        @default_gateway = nil
        if gateway.is_a?(Hash)
          @options[:logger].debug "Creating multiple gateways using #{gateway.inspect}" if @options[:logger]
          gateway.each do |gw, hosts|
            gateway_connection = add_gateway(gw)
            Array(hosts).each do |host|
              # Why is the default only set if there's at least one host?
              # It seems odd enough to be intentional, since it could easily be set outside of the loop.
              @default_gateway ||= gateway_connection
              @gateways[host] = gateway_connection
            end
          end
        else
          @options[:logger].debug "Creating gateway using #{Array(gateway).join(', ')}" if @options[:logger]
          @default_gateway = add_gateway(gateway)
        end
      end

      def add_gateway(gateway)
        gateways = ServerDefinition.wrap_list(gateway)

        tunnel = SSH.gateway(gateways.shift, @options)

        gateways.inject(tunnel) do |tunnel, destination|
          @options[:logger].debug "Creating tunnel to #{destination}" if @options[:logger]
          local = local_host(destination, tunnel)
          SSH.gateway(local, @options)
        end
      end

      def connect_to(server)
        @options[:logger].debug "establishing connection to `#{server}' via gateway" if @options[:logger]
        local = local_host(server, gateway_for(server))
        session = SSH.connect(local, @options)
        session.xserver = server
        session
      end

      def local_host(destination, tunnel)
        ServerDefinition.new("127.0.0.1", :user => destination.user, :port => tunnel.open(destination.host, destination.connect_to_port))
      end

      def gateway_for(server)
        @gateways[server.host] || @default_gateway
      end
    end

    # Instantiates a new ConnectionManager object.
    # +options+ must be a hash containing any of the following keys:
    #
    # * +gateway+: (optional), ssh gateway
    # * +logger+: (optional), a Capissh::Logger instance
    # * +ssh_options+: (optional), options for Net::SSH
    # * +verbose+: (optional), verbosity level for ssh
    # * +user+: (optional), user for all servers
    # * +port+: (optional), port for all servers
    # * +password+: (optional), password for all servers
    #
    # * many more that I haven't written yet
    #
    def initialize(options={})
      @options = options.dup
      @gateway = @options.delete(:gateway)
      @logger  = @options[:logger] || Capissh::Logger.default
      Thread.current[:sessions] = {}
      Thread.current[:failed_sessions] = []
    end

    attr_reader :logger

    # A hash of the SSH sessions that are currently open and available.
    # Because sessions are constructed lazily, this will only contain
    # connections to those servers that have been the targets of one or more
    # executed tasks. Stored on a per-thread basis to improve thread-safety.
    def sessions
      Thread.current[:sessions] ||= {}
    end

    # Indicate that the given server could not be connected to.
    def failed!(server)
      Thread.current[:failed_sessions] << server
    end

    # Query whether previous connection attempts to the given server have
    # failed.
    def has_failed?(server)
      Thread.current[:failed_sessions].include?(server)
    end

    # Used to force connections to be made to the current task's servers.
    # Connections are normally made lazily in Capissh--you can use this
    # to force them open before performing some operation that might be
    # time-sensitive.
    def connect!(servers, options={})
      execute_on_servers(servers, options) { }
    end

    # Returns the object responsible for establishing new SSH connections.
    # The factory will respond to #connect_to, which can be used to
    # establish connections to servers defined via ServerDefinition objects.
    def connection_factory
      @connection_factory ||= begin
        if @gateway
          logger.debug "establishing connection to gateway `#{@gateway.inspect}'"
          GatewayConnectionFactory.new(@gateway, @options)
        else
          DefaultConnectionFactory.new(@options)
        end
      end
    end

    # Ensures that there are active sessions for each server in the list.
    def establish_connections_to(servers)
      # force the connection factory to be instantiated synchronously,
      # otherwise we wind up with multiple gateway instances, because
      # each connection is done in parallel.
      connection_factory

      failed_servers = []
      servers_array = Array(servers)

      threads = servers_array.map { |server| establish_connection_to(server, failed_servers) }
      threads.each { |t| t.join }

      if failed_servers.any?
        messages = failed_servers.map { |h| "#{h[:server]} (#{h[:error].class}: #{h[:error].message})" }
        error = ConnectionError.new("connection failed for: #{messages.join(', ')}")
        error.hosts = failed_servers.map { |h| h[:server] }.each {|server| failed!(server) }
        raise error
      end
    end

    # Destroys sessions for each server in the list.
    def teardown_connections_to(servers)
      servers.each do |server|
        begin
          sessions.delete(server).close
        rescue IOError
          # the TCP connection is already dead
        end
      end
    end

    # Determines the set of servers and establishes connections to them,
    # and then yields that list of servers.
    #
    # All options will be used to find servers. (see find_servers)
    #
    # The additional options below will also be used as follows:
    #
    # * +continue_on_no_matching_servers+: (optional), set to :continue to return
    #   instead of raising when no servers are found
    # * +max_hosts+: (optional), integer to batch commands in chunks of hosts
    # * +continue_on_error+: (optional), continue on connection errors
    #
    def execute_on_servers(servers, options={}, &block)
      raise ArgumentError, "expected a block" unless block_given?

      connect_to_servers = ServerDefinition.wrap_list(*servers)

      if options[:continue_on_error]
        connect_to_servers.delete_if { |s| has_failed?(s) }
      end

      if connect_to_servers.empty?
        raise Capissh::NoMatchingServersError, "no servers found to match #{options.inspect}" unless options[:continue_on_no_matching_servers]
        return
      end

      logger.trace "servers: #{connect_to_servers.map { |s| s.host }.inspect}"

      max_hosts = (options[:max_hosts] || connect_to_servers.size).to_i
      is_subset = max_hosts < connect_to_servers.size

      if max_hosts <= 0
        raise Capissh::NoMatchingServersError, "max_hosts is invalid for #{options.inspect}" unless options[:continue_on_no_matching_servers]
        return
      end

      # establish connections to those servers in groups of max_hosts, as necessary
      connect_to_servers.each_slice(max_hosts) do |servers_slice|
        begin
          establish_connections_to(servers_slice)
        rescue ConnectionError => error
          raise error unless options[:continue_on_error]
          error.hosts.each do |h|
            servers_slice.delete(h)
            failed!(h)
          end
        end

        begin
          yield Sessions.new(servers_slice.map { |server| sessions[server] })
        rescue RemoteError => error
          raise error unless options[:continue_on_error]
          error.hosts.each { |h| failed!(h) }
        end

        # if dealing with a subset (e.g., :max_hosts is less than the
        # number of servers available) teardown the subset of connections
        # that were just made, so that we can make room for the next subset.
        teardown_connections_to(servers_slice) if is_subset
      end
    end

    private

    # We establish the connection by creating a thread in a new method--this
    # prevents problems with the thread's scope seeing the wrong 'server'
    # variable if the thread just happens to take too long to start up.
    def establish_connection_to(server, failures=nil)
      current_thread = Thread.current
      Thread.new { safely_establish_connection_to(server, current_thread, failures) }
    end

    def safely_establish_connection_to(server, thread, failures=nil)
      thread[:sessions] ||= {} # can this move up to the current_thread part above?
      thread[:sessions][server] ||= connection_factory.connect_to(server)
    rescue Exception => err
      raise unless failures
      failures << { :server => server, :error => err }
    end
  end
end
