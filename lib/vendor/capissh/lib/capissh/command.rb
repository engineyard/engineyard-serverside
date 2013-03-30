require 'benchmark'
require 'capissh/errors'
require 'capissh/command_tree'

module Capissh

  # This class encapsulates a single command to be executed on a set of remote
  # machines, in parallel.
  class Command
    class << self
      attr_accessor :default_io_callback

      def process_tree(tree, sessions, options={})
        new(tree, options).call(sessions)
      end
      alias process process_tree

      # Convenience method to process a command given as a string
      # rather than a CommandTree.
      def process_string(string, sessions, options={}, &block)
        tree = CommandTree.twig(nil, string, &block)
        process_tree(tree, sessions, options)
      end
    end

    self.default_io_callback = Proc.new do |ch, stream, out|
      if ch[:logger]
        level = stream == :err ? :important : :info
        ch[:logger].send(level, out, "#{stream} :: #{ch[:server]}")
      end
    end

    attr_reader :tree, :options

    # Instantiates a new command object.
    #
    # The +command+ must be a string containing the command to execute.
    # +options+ must be a hash containing any of the following keys:
    #
    # * +logger+: (optional), a Capissh::Logger instance
    # * +data+: (optional), a string to be sent to the command via it's stdin
    # * +eof+: (optional), close stdin after sending data
    # * +pty+: (optional), execute the command in a pty
    def initialize(tree, options={})
      @tree = tree
      @options = options
    end

    # Processes the command in parallel on all specified hosts. If the command
    # fails (non-zero return code) on any of the hosts, this will raise a
    # Capissh::CommandError.
    def call(sessions)
      channels = sessions.map do |session|
        open_channels(session)
      end.flatten

      elapsed = Benchmark.realtime do
        loop do
          active = sessions.process_iteration do
            channels.any? { |ch| !ch[:closed] }
          end
          break unless active
        end
      end

      logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger

      failed = channels.select { |ch| ch[:status] != 0 }
      if failed.any?
        handle_failed(failed)
      end

      self
    end

    def handle_failed(failed)
      commands = failed.group_by { |ch| ch[:command] }
      message = commands.map { |command, channels| "#{command.inspect} on #{channels.map{|ch| ch[:server]}.join(',')}" }
      error = CommandError.new("failed: #{message.join("; ")}")
      error.hosts = failed.map { |ch| ch[:server] }.uniq
      raise error
    end

    private

      def logger
        options[:logger]
      end

      def open_channels(session)
        server = session.xserver
        @tree.base_command_and_callback(server).map do |command, io_callback|
          session.open_channel do |channel|
            channel[:server] = server
            channel[:options] = options
            channel[:logger] = logger
            command.force_encoding('BINARY') if command.respond_to?(:force_encoding)
            channel[:command] = command
            channel[:io_callback] = io_callback

            request_pty_if_necessary(channel) do |ch|
              logger.trace "executing command", ch[:server] if logger
              ch.exec(channel[:command])
              ch.send_data(options[:data]) if options[:data]
              ch.eof! if options[:eof]
            end

            channel.on_data do |ch, data|
              ch[:io_callback].call(ch, :out, data)
            end

            channel.on_extended_data do |ch, type, data|
              ch[:io_callback].call(ch, :err, data)
            end

            channel.on_request("exit-status") do |ch, data|
              ch[:status] = data.read_long
            end

            channel.on_close do |ch|
              ch[:closed] = true
            end
          end
        end
      end

      def request_pty_if_necessary(channel)
        if options[:pty]
          channel.request_pty do |ch, success|
            if success
              yield ch
            else
              # just log it, don't actually raise an exception, since the
              # process method will see that the status is not zero and will
              # raise an exception then.
              logger.important "could not open channel", ch[:server] if logger
              ch.close
            end
          end
        else
          yield channel
        end
      end

  end
end
