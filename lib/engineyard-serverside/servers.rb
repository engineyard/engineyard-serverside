require 'engineyard-serverside/server'
require 'forwardable'
require 'set'
require 'engineyard-serverside/spawner'

module EY
  module Serverside
    class Servers
      class DuplicateHostname < StandardError
        def initialize(hostname)
          super "EY::Serverside::Server '#{hostname}' duplicated!"
        end
      end

      ## Array compatibility
      extend Forwardable
      include Enumerable

      def_delegators :servers, :each, :size, :empty?



      attr_reader :servers, :shell, :cache

      def initialize(servers, shell)
        @servers = servers
        @shell = shell
        @cache = {}
      end

      def self.from_hashes(server_hashes, shell)
        seen = []

        servers = server_hashes.map {|server_hash|
          server = Server.from_hash(server_hash)
          hostname = server.hostname

          raise DuplicateHostname.new(hostname) if seen.include?(hostname)

          seen.push(hostname)
          server
        }

        new(servers, shell)
      end
      
      
        #
      def select(*a, &b)
        self.class.new @servers.select(*a,&b), @shell
      end

      def reject(*a, &b)
        self.class.new @servers.reject(*a,&b), @shell
      end

      def to_a()
        @servers
      end

      def ==(other)
        other.respond_to?(:to_a) && other.to_a == to_a
      end

      def self.from_hashes(server_hashes, shell)
        servers = server_hashes.inject({}) do |memo, server_hash|
          server = Server.from_hash(server_hash)
          raise DuplicateHostname.new(server.hostname) if memo.key?(server.hostname)
          memo[server.hostname] = server
          memo
        end
        new(servers.values, shell)
      end

      def initialize(servers, shell)
        @servers = servers
        @shell = shell
        @cache = {}
      end

      def localhost
        @servers.find {|server| server.local? }
      end

      def remote
        reject { |server| server.local? }
      end

      def in_groups(number)
        div, mod = size.divmod number
        start = 0
        number.times do |index|
          length = div + (mod > 0 && mod > index ? 1 : 0)
          yield self.class.new(@servers.slice(start, length), @shell)
          start += length
        end
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

      def run_on_each(cmd, &block)
        run_for_each do |server|
          server.command_on_server('sh -l -c', cmd, &block)
        end
      end

      # Run a command on this set of servers.
      def run_on_each!(cmd, &block)
        run_for_each! do |server|
          server.command_on_server('sh -l -c', cmd, &block)
        end
      end
      alias run run_on_each!

      # Run a sudo command on this set of servers.
      def sudo_on_each(cmd, &block)
        run_for_each do |server|
          server.command_on_server('sudo sh -l -c', cmd, &block)
        end
      end

      # Run a sudo command on this set of servers.
      def sudo_on_each!(cmd, &block)
        run_for_each! do |server|
          server.command_on_server('sudo sh -l -c', cmd, &block)
        end
      end
      alias sudo sudo_on_each!

      def run_for_each(&block)
        spawner = Spawner.new
        each { |server| spawner.add(block.call(server), @shell, server) }
        spawner.run
      end

      def run_for_each!(&block)
        failures = run_for_each(&block).reject {|result| result.success? }

        if failures.any?
          commands = failures.map { |f| f.command }.uniq
          servers = failures.map { |f| f.server }.compact.map { |s| s.inspect }
          outputs = failures.map { |f| f.output }.uniq
          message = "The following command#{commands.size == 1 ? '' : 's'} failed"
          if servers.any?
            message << " on server#{servers.size == 1 ? '' : 's'} [#{servers.join(', ')}]"
          end
          message << "\n\n"
          commands.each do |cmd|
            message << "$ #{cmd}\n"
          end
          message << "\n" << outputs.join("\n\n") << "\n"
          raise EY::Serverside::RemoteFailure.new(message)
        end
      end

    end
  end
end
