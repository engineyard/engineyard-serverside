require 'net/scp'

module Capissh
  class Transfer
    class SCP
      def self.open(*args)
        new(*args).open
      end

      attr_reader :direction, :from, :to, :session, :options, :callback, :logger, :channel, :error

      def initialize(direction, from, to, session, options={}, &block)
        @direction = direction
        @from      = from
        @to        = to
        @session   = session
        @options   = options
        @logger    = options.delete(:logger)
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
        @channel = session.scp.upload(from, to, options, &callback)
        augment_channel
        self
      end

      def download
        @channel = session.scp.download(from, to, options, &callback)
        augment_channel
        self
      end

      def augment_channel
        channel[:server] = server
        channel[:host]   = server.host
      end

      def server
        session.xserver
      end

      def active?
        channel && channel.active?
      end

      def close
        channel && channel.close
      end

      def failed(error)
        @error = error
        close
      end

      def failed?
        !!error
      end

      def default_callback
        Proc.new do |ch, name, sent, total|
          logger.trace "[#{ch[:host]}] #{name}" if logger && sent == 0
        end
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
