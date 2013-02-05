require 'logger'
require 'pathname'
require 'session'
require 'engineyard-serverside/shell/formatter'
require 'engineyard-serverside/shell/command_result'
require 'engineyard-serverside/shell/yieldio'

module EY
  module Serverside
    class Shell
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

      def fatal(msg)   logger.fatal   "FATAL: #{msg}"   end
      def error(msg)   logger.error   "ERROR: #{msg}"   end
      def warning(msg) logger.warn    "WARNING: #{msg}" end
      def notice(msg)  logger.warn    msg end
      def info(msg)    logger.info    msg end
      def debug(msg)   logger.debug   msg end
      def unknown(msg) logger.unknown msg end

      # a debug outputter that displays a command being run
      # Formatis like this:
      #   $ cmd blah do \
      #   > something more
      #   > end
      def show_command(cmd)
        debug cmd.gsub(/^/, '   > ').sub(/>/, '$')
      end

      def logged_system(cmd)
        show_command(cmd)
        output = ""
        outio = YieldIO.new { |msg| output << msg; debug   msg.gsub(/^/,'     ') }
        errio = YieldIO.new { |msg| output << msg; unknown msg.gsub(/^/,'     ') }
        result = spawn_process(cmd, outio, errio)
        CommandResult.new(cmd, result.exitstatus, output)
      end

      protected

      # This is the meat of process spawning. It's nice to keep it separate even
      # though it's simple because we've had to modify it frequently.
      def spawn_process(cmd, outio, errio)
        Session::new do |sh|
          sh.execute(cmd) do |out, err|
            outio << out if out
            errio << err if err
          end
          sh.exit_status
        end
      end
    end
  end
end
