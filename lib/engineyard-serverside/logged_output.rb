require 'open4'

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

      # TODO color output
      def error(msg)
        info(msg)
      end

      def info(msg)
        with_logfile do |log|
          Tee.new($stdout, log) << (msg + "\n")
        end
      end

      def debug(msg)
        with_logfile do |log|
          log << "#{msg}\n"
        end
      end

      def logged_system(cmd)
        with_logfile do |log|
          out = verbose? ? Tee.new($stdout, log) : log
          err = Tee.new($stderr, log)    # we always want to see errors

          out <<  ":: running #{cmd}\n"

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

    end
  end
end
