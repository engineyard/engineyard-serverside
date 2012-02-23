require 'logger'
require 'pathname'
require 'open4'
require 'engineyard-serverside/shell/formatter'

module EY
  module Serverside
    class Shell
      class YieldIO
        def initialize(&block)
          @block = block
        end
        def <<(str)
          @block.call str
        end
      end

      attr_reader :logger

      def initialize(options)
        @start_time = options[:start_time]
        @verbose    = options[:verbose]


        @stdout = options[:stdout] || $stdout
        @stderr = options[:stderr] || $stderr

        log_pathname = Pathname.new(options[:log_path])
        log_pathname.unlink if log_pathname.exist? # start fresh
        @logger = Logger.new(log_pathname.to_s)
        @logger.level = Logger::DEBUG # Always log to the file at debug, formatter hides debug for non-verbose
        @logger.formatter = EY::Serverside::Shell::Formatter.new(@stdout, @stderr, start_time, @verbose)
      end

      def start_time
        @start_time ||= Time.now
      end

      # a nice info outputter that prepends spermy operators for some reason.
      def status(msg)
        info msg.gsub(/^/, '~> ')
      end

      def substatus(msg)
        debug msg.gsub(/^/, ' ~ ')
      end

      # a debug outputter that displays a command being run
      # Formatis like this:
      #   $ cmd blah do \
      #   > something more
      #   > end
      def show_command(cmd)
        debug cmd.gsub(/^/, '   > ').sub(/>/, '$')
      end

      def command_stdout(msg)
        debug msg.gsub(/^/,'     ')
      end

      def command_stderr(msg)
        unknown msg.gsub(/^/,'     ')
      end

      def fatal(msg)   logger.fatal   msg end
      def error(msg)   logger.error   msg end
      def warning(msg) logger.warn    msg end
      def info(msg)    logger.info    msg end
      def debug(msg)   logger.debug   msg end
      def unknown(msg) logger.unknown msg end

      # Return an IO that outputs to stdout or not according to the verbosity settings
      # debug is hidden in non-verbose mode
      def out
        YieldIO.new { |msg| command_stdout(msg) }
      end

      # Return an IO that outputs to stderr
      # unknown always shows, but without a severity title
      def err
        YieldIO.new { |msg| command_stderr(msg) }
      end

      def logged_system(cmd)
        show_command(cmd)
        spawn_process(cmd, out, err)
      end

      protected

      # spawn_process is a separate utility method so tests can override just the meat
      # of the process spawning and not couple the tests too tightly with the implementation.
      # we do this because Open4 LOVES to segfault in CI. FUN!
      def spawn_process(cmd, cmd_stdout, cmd_stderr)
        # :quiet means don't raise an error on nonzero exit status
        result = Open4.spawn cmd, 0 => '', 1 => cmd_stdout, 2 => cmd_stderr, :quiet => true
        result.exitstatus == 0
      end
    end
  end
end
