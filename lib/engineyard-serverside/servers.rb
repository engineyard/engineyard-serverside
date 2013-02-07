require 'engineyard-serverside/server'
require 'forwardable'
require 'set'

module EY
  module Serverside
    class Servers

      class DuplicateHostname < StandardError
        def initialize(hostname)
          super "EY::Serverside::Server '#{hostname}' duplicated!"
        end
      end

      # Array compatibility
      extend Forwardable
      include Enumerable
      def_delegators :@servers, :each, :size, :empty?
      def select(*a, &b) self.class.new @servers.select(*a,&b) end
      def reject(*a, &b) self.class.new @servers.reject(*a,&b) end
      def to_a() @servers end
      def ==(other) other.respond_to?(:to_a) && other.to_a == to_a end


      def self.from_hashes(server_hashes)
        servers = server_hashes.inject({}) do |memo, server_hash|
          server = Server.from_hash(server_hash)
          raise DuplicateHostname.new(server.hostname) if memo.key?(server.hostname)
          memo[server.hostname] = server
          memo
        end
        new(servers.values)
      end

      def initialize(servers)
        @servers = servers
        @cache = {}
      end

      def localhost
        @servers.find {|server| server.local? }
      end

      def remote
        reject { |server| server.local? }
      end

      # We look up the same set of servers over and over.
      # Cache them so we don't have to find them every time
      # Accepts a block (because it's confusing when you send a block to this
      # method and it doesn't yield and it's better than raising)
      def roles(*select_roles, &block)
        if block_given?
          return yield(roles(*select_roles))
        end

        roles_set = Set.new select_roles.flatten.compact.map{|r| r.to_sym}
        if roles_set.empty? || roles_set.include?(:all)
          self
        else
          @cache[roles_set] ||= select { |server| server.matches_roles?(roles_set) }
        end
      end

      # Run a command on this set of servers.
      def run(shell, cmd, &block)
        run_on_each do |server|
          exec_cmd = server.command_on_server('sh -l -c', cmd, &block)
          shell.logged_system(exec_cmd)
        end
      end

      # Run a sudo command on this set of servers.
      def sudo(shell, cmd, &block)
        run_on_each do |server|
          exec_cmd = server.command_on_server('sudo sh -l -c', cmd, &block)
          shell.logged_system(exec_cmd)
        end
      end

      # Makes a thread for each server and executes the block,
      # returning an array of return values
      def map_in_parallel(&block)
        threads = map { |server| Thread.new { block.call(server) } }
        threads.map { |t| t.value }
      end

      def select_in_parallel(&block)
        results = map_in_parallel { |server| block.call(server) ? server : nil }.compact
        self.class.new results
      end

      # Makes a theard for each server and executes the block,
      # Assumes that the return value of the block is a CommandResult
      # and ensures that all the command results were successful.
      def run_on_each(&block)
        results = map_in_parallel(&block)
        failures = results.reject {|result| result.success? }
        if failures.any?
          message = failures.map { |f| f.inspect }.join("\n")
          raise EY::Serverside::RemoteFailure.new(failures)
        end
      end

    end
  end
end
