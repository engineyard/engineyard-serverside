require 'open4'

module EY
  module LoggedOutput

    class Tee
      def initialize(*streams)
        @streams = streams.flatten
      end

      def <<(output)
        @streams.each { |s| s << output }
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
      EY::LoggedOutput.verbose?
    end

    def logfile
      EY::LoggedOutput.logfile
    end

    def logged_system(cmd)
      File.open(logfile, 'a') do |log|
        out = verbose? ? Tee.new($stdout, log) : log
        err = Tee.new($stderr, log)    # we always want to see errors

        out <<  ":: running #{cmd}\n"

        # :quiet means don't raise an error on nonzero exit status
        status = Open4.spawn cmd, 0 => '', 1 => out, 2 => err, :quiet => true
        status.exitstatus == 0
      end
    end

  end
end
