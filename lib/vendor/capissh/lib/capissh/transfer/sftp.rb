require 'net/sftp'

module Capissh
  class Transfer
    class SFTP
      def self.open(*args)
        new(*args).open
      end

      attr_reader :direction, :from, :to, :session, :options, :callback, :logger, :error

      def initialize(direction, from, to, session, options={}, &block)
        @direction = direction
        @from      = from
        @to        = to
        @session   = session

        @logger    = options.delete(:logger)

        @options   = options.dup
        @options[:properties] ||= {}
        @options[:properties][:server] = server
        @options[:properties][:host]   = server.host

        @callback  = block || default_callback

        unless [:up,:down].include?(@direction)
          raise ArgumentError, "unsupported transfer direction: #{@direction.inspect}"
        end
      end

      def open
        case direction
        when :up   then upload
        when :down then download
        end
      end

      def upload
        session.sftp(false).connect do |sftp|
          @transfer = sftp.upload(from, to, options, &callback)
        end
        self
      end

      def download
        session.sftp(false).connect do |sftp|
          @transfer = sftp.download(from, to, options, &callback)
        end
        self
      end

      def server
        session.xserver
      end

      def default_callback
        Proc.new do |event, op, *args|
          if event == :open
            logger.trace "[#{op[:host]}] #{args[0].remote}"
          elsif event == :finish
            logger.trace "[#{op[:host]}] done"
          end
        end
      end

      def active?
        @transfer.nil? || @transfer.active?
      end

      def close
        @transfer.abort!
      end

      def failed(error)
        @error = error
        close
      end

      def failed?
        !!error
      end

      def inspect
        "#<#{self.class} #{state} #{direction}load #{sanitized_from} -> #{sanitized_to} on #{server}>"
      end

      def state
        if    active? then "active"
        elsif failed? then "failed"
        else               "pending"
        end
      end

      def sanitized_from
        from.responds_to?(:read) ? "#<#{from.class}>" : from
      end

      def sanitized_to
        to.responds_to?(:read) ? "#<#{to.class}>" : to
      end
    end
  end
end
