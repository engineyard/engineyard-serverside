require 'net/scp'
require 'net/sftp'

require 'capissh/errors'
require 'capissh/transfer/scp'
require 'capissh/transfer/sftp'

module Capissh
  class Transfer
    class << self
      attr_accessor :transfer_types
    end
    self.transfer_types = {
      :scp  => Transfer::SCP,
      :sftp => Transfer::SFTP,
    }

    def self.process(direction, from, to, sessions, options={}, &block)
      new(direction, from, to, options, &block).call(sessions)
    end

    attr_reader :options
    attr_reader :callback

    attr_reader :transport
    attr_reader :direction
    attr_reader :from
    attr_reader :to

    attr_reader :logger

    def initialize(direction, from, to, options={}, &block)
      @direction = direction
      @from      = from
      @to        = to
      @options   = options
      @callback  = block

      @transport = options.fetch(:via, :sftp)
      @logger    = options[:logger]

      @transfer_class = self.class.transfer_types[@transport]
      unless @transfer_class
        raise ArgumentError, "unsupported transport type: #{@transport.inspect}"
      end

      unless [:up,:down].include?(@direction)
        raise ArgumentError, "unsupported transfer direction: #{@direction.inspect}"
      end
    end

    def call(sessions)
      session_map = {}
      transfers = sessions.map do |session|
        session_map[session] = open_transfer(session)
      end

      loop do
        begin
          active = sessions.process_iteration do
            transfers.any? { |transfer| transfer.active? }
          end
          break unless active
        rescue Exception => error
          raise error if error.message.include?('expected a file to upload')
          if error.respond_to?(:session)
            transfer = session_map[error.session]
            transfer.failed(error)
          else
            raise
          end
        end
      end

      failed = transfers.select { |transfer| transfer.failed? }
      if failed.any?
        handle_failed(failed)
      end

      logger.debug "#{transport} #{operation} complete" if logger
      self
    end

    def handle_failed(failed)
      hosts = failed.map { |transfer| transfer.server }
      errors = failed.map { |transfer| "#{transfer.error} (#{transfer.error.message})" }.uniq.join(", ")
      error = TransferError.new("#{operation} via #{transport} failed on #{hosts.join(',')}: #{errors}")
      error.hosts = hosts
      logger.important(error.message) if logger
      raise error
    end

    def intent
      "#{transport} #{operation} #{sanitized_from} -> #{sanitized_to}"
    end

    def operation
      "#{direction}load"
    end

    def sanitized_from
      from.responds_to?(:read) ? "#<#{from.class}>" : from
    end

    def sanitized_to
      to.responds_to?(:read) ? "#<#{to.class}>" : to
    end

    private

      def open_transfer(session)
        session_from = normalize(from, session)
        session_to   = normalize(to,   session)
        @transfer_class.open(direction, session_from, session_to, session, options, &callback)
      end

      def normalize(argument, session)
        if argument.is_a?(String)
          Configuration.default_placeholder_callback.call(argument, session.xserver)
        elsif argument.respond_to?(:read)
          pos = argument.pos
          clone = StringIO.new(argument.read)
          clone.pos = argument.pos = pos
          clone
        else
          argument
        end
      end
  end
end
