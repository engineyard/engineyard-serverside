require 'capissh/server_definition'

module Capissh
  class Role
    include Enumerable

    def initialize(*list)
      @static_servers = []
      @dynamic_servers = []
      push(*list)
    end

    def each(&block)
      servers.each &block
    end

    def push(*list)
      options = list.last.is_a?(Hash) ? list.pop : {}
      list.each do |item|
        if item.respond_to?(:call)
          @dynamic_servers << DynamicServerList.new(item, options)
        else
          @static_servers << ServerDefinition.wrap_server(item, options)
        end
      end
    end
    alias_method :<<, :push

    def servers
      @static_servers + dynamic_servers
    end
    alias_method :to_ary, :servers

    def empty?
      servers.empty?
    end

    def clear
      @dynamic_servers.clear
      @static_servers.clear
    end

    def include?(server)
      servers.include?(server)
    end

    protected

    # This is the combination of a block, a hash of options, and a cached value.
    class DynamicServerList
      def initialize(block, options)
        @block = block
        @options = options
        @cached = []
        @is_cached = false
      end

      # Convert to a list of ServerDefinitions
      def to_ary
        unless @is_cached
          @cached = ServerDefinition.wrap_list(@block.call(@options), @options)
          @is_cached = true
        end
        @cached
      end

      # Clear the cached value
      def reset!
        @cached.clear
        @is_cached = false
      end
    end

    # Attribute reader for the cached results of executing the blocks in turn
    def dynamic_servers
      @dynamic_servers.inject([]) { |list, item| list.concat item }
    end

  end
end
