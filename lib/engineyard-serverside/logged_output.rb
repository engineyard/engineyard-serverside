module EY
  module Serverside
    module LoggedOutput

      class Tee
        def initialize(*streams)
          @streams = streams.flatten
        end

        def <<(output)
          @streams.each do |s|
            s << output
            s.flush
          end
          self
        end
      end # Tee

      @@logfile = File.join(ENV['HOME'], 'ey.log')
      def self.logfile=(filename)
        File.unlink filename if File.exist?(filename)  # start fresh
        @@logfile = filename
      end

      def self.logfile
        @@logfile
      end

      @@verbose = false
      def self.verbose=(v)
        @@verbose = !!v
      end

      def self.verbose?
        @@verbose
      end

      def verbose?
        EY::Serverside::LoggedOutput.verbose?
      end

      def warning(msg)
        info "WARNING: #{msg}\n".gsub(/^/,'!> ')
      end

      def info(msg)
        with_logfile do |log|
          Tee.new($stdout, log) << ("#{with_timestamp(msg)}\n")
        end
      end

      def debug(msg)
        with_logfile do |log|
          log << "#{with_timestamp(msg)}\n"
        end
      end

      def logged_system(cmd)
        with_logfile do |log|
          out = verbose? ? Tee.new($stdout, log) : log
          err = Tee.new($stderr, log)    # we always want to see errors

          out <<  with_timestamp(":: running #{cmd}\n")

          # :quiet means don't raise an error on nonzero exit status
          status = Open4.spawn cmd, 0 => '', 1 => out, 2 => err, :quiet => true
          status.exitstatus == 0
        end
      end

      private
      def with_logfile
        File.open(logfile, 'a') {|f| yield f }
      end

      def logfile
        EY::Serverside::LoggedOutput.logfile
      end

      def with_timestamp(msg)
        return msg unless respond_to?(:starting_time)
        time_passed = Time.now.to_i - starting_time.to_i
        timestamp   = "+%2dm %02ds " % time_passed.divmod(60)
        msg.gsub(/^/, timestamp)
      end
    end
  end
end
