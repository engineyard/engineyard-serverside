require 'enumerator'
require 'net/ssh/gateway'
require 'capissh/ssh'
require 'capissh/errors'
require 'capissh/server_definition'
require 'capissh/logger'

module Capissh
  class ServersSet
    attr_reader :servers

    # Instantiates a set of servers.
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
    def initialize(servers, options={})
      @servers = servers
      @options = options.dup
      @logger  = @options[:logger] || Capissh::Logger.default
    end

    def connections
      @connections ||= Capissh::Connections.new(@options.merge(:logger => @logger))
    end


    # FIXME Remove this method. This method should be where it belongs.
    # self methods need to be dealt with. They shouldn't be accessed directly.
    def run(cmd, options={})
      self.with_connections(options) do |sessions| # FIXME: execute_on_servers shouldn't be accessed directly (replace self with object)
        Command.process(cmd, sessions, options.merge(:logger => logger))
      end
    end

    attr_reader :logger

    def sessions
      connections.sessions
    end

    # Query whether previous connection attempts to the given server have
    # failed.
    def has_failed?(server)
      connections.has_failed?(server)
    end

    # Used to force connections to be made to the current task's servers.
    # Connections are normally made lazily in Capissh--you can use this
    # to force them open before performing some operation that might be
    # time-sensitive.
    def connect!(options={})
      with_connections(options) { }
    end

    # Ensures that there are active sessions for each server in the list.
    def establish_connections_to(servers)
      failed_servers = []

      # force the connection factory to be instantiated synchronously,
      # otherwise we wind up with multiple gateway instances, because
      # each connection is done in parallel.
      connection_factory

      threads = Array(servers).map { |server| establish_connection_to(server, failed_servers) }
      threads.each { |t| t.join }

      if failed_servers.any?
        messages = failed_servers.map { |h| "#{h[:server]} (#{h[:error].class}: #{h[:error].message})" }
        error = ConnectionError.new("connection failed for: #{messages.join(', ')}")
        error.hosts = failed_servers.map { |h| h[:server] } #.each { |server| failed!(server) }
        raise error
      end
    end

    # Destroys sessions for each server in the list.
    def teardown_connections
      connections.teardown_connections_to(servers)
      #servers.each do |server|
      #  connections.teardown_connection_to(server)
      #end
    end

    # Determines the set of servers and establishes connections to them,
    # and then yields that list of servers.
    #
    # All options will be used to find servers. (see find_servers)
    #
    # The additional options below will also be used as follows:
    #
    # * +on_no_matching_servers+: (optional), set to :continue to return
    #   instead of raising when no servers are found
    # * +once+: (optional), if truthy, runs the command on only one server
    # * +max_hosts+: (optional), positive integer to open connections in chunks
    # * +continue_on_error+: (optional), continue on connection errors
    #      automatically skipping servers that have failed previously
    #
    def with_connections(options={}, &block)
      raise ArgumentError, "expected a block" unless block_given?

      connect_to_servers = servers.dup

      if options[:continue_on_error]
        connect_to_servers.delete_if { |s| has_failed?(s) }
      end

      if connect_to_servers.empty?
        raise Capissh::NoMatchingServersError, "no servers found to match #{options.inspect}" if options[:on_no_matching_servers] != :continue
        return
      end

      connect_to_servers = [connect_to_servers.first] if options[:once]
      logger.trace "servers: #{connect_to_servers.map { |s| s.host }.inspect}"

      max_hosts = (options[:max_hosts] || connect_to_servers.size).to_i
      is_subset = max_hosts < connect_to_servers.size

      if max_hosts <= 0
        raise Capissh::NoMatchingServersError, "max_hosts is invalid for #{options.inspect}" if options[:on_no_matching_servers] != :continue
        return
      end

      # establish connections to those servers in groups of max_hosts, as necessary
      connect_to_servers.each_slice(max_hosts) do |servers_slice|
        begin
          sessions = connections.establish_connections_to(servers_slice) # FIXME sessions is leaky
        rescue ConnectionError => error
          raise error unless options[:continue_on_error]
          error.hosts.each do |h|
            servers_slice.delete(h)
            failed!(h)
          end
        end

        begin
          yield sessions # FIXME sessions is leaky
        rescue RemoteError => error
          raise error unless options[:continue_on_error]
          error.hosts.each { |h| failed!(h) }
        end

        # if dealing with a subset (e.g., :max_hosts is less than the
        # number of servers available) teardown the subset of connections
        # that were just made, so that we can make room for the next subset.
        connections.teardown_connections_to(servers_slice) if is_subset
      end
    end
  end
end
