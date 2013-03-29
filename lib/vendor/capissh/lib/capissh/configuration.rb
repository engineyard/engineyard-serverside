require 'capissh/logger'
require 'capissh/command'
require 'capissh/connection_manager'
require 'capissh/invocation'
require 'capissh/file_transfers'
require 'forwardable'

module Capissh
  # Represents a specific Capissh configuration.
  class Configuration
    extend Forwardable

    class << self
      attr_accessor :default_placeholder_callback
    end

    self.default_placeholder_callback = proc do |command, server|
      command.gsub(/\$CAPISSH:HOST\$/, server.host)
    end

    attr_reader :logger, :options

    def initialize(options={})
      @options = options.dup
      @logger = Capissh::Logger.new(@options)
      @options[:default_environment] ||= {}
      @options[:default_run_options] ||= {}
      @options[:default_shell] ||= nil
    end

    def set(key, value)
      @options[key.to_sym] = value
    end
    alias []= set

    def fetch(key, *args, &block)
      @options.fetch(key.to_sym, *args, &block)
    end
    alias [] fetch

    def dry_run
      fetch :dry_run, false
    end

    def placeholder_callback
      fetch :placeholder_callback, self.class.default_placeholder_callback
    end

    def execute_on_servers(servers, options, &block)
      unless dry_run
        connection_manager.execute_on_servers(servers, options, &block)
      end
    end

    def connection_manager
      @connection_manager ||= ConnectionManager.new(@options.merge(:logger => logger))
    end

    def file_transfers
      @file_transfers ||= FileTransfers.new(self, logger)
    end
    def_delegators :file_transfers, :put, :get, :upload, :download, :transfer

    def invocation
      @invocation ||= Invocation.new(self, logger)
    end
    def_delegators :invocation, :parallel, :invoke_command, :run, :sudo, :sudo_command
  end
end
