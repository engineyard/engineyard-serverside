require 'logger'
require 'pathname'
require 'engineyard-serverside/shell/formatter'
require 'engineyard-serverside/shell/yieldio'

module EY
  module Serverside
    class Shell
      STATUS_PREFIX    = '~> '.freeze
      SUBSTATUS_PREFIX = ' ~ '.freeze
      IMPORTANT_PREFIX = '!> '.freeze
      CMD_PREFIX       = '   $ '.freeze
      CMD_CONTINUE     = '   > '.freeze
      CMD_INDENT       = '     '.freeze
      BOL = /^/.freeze

      include Logger::Severity

      attr_reader :logger, :start_time

      def initialize(options)
        @start_time = options[:start_time] || Time.now
        @verbose    = options[:verbose]

        @stdout = options[:stdout] || $stdout
        @stderr = options[:stderr] || $stderr

        log_pathname = Pathname.new(options[:log_path])
        log_pathname.unlink if log_pathname.exist? # start fresh
        @logger = Logger.new(log_pathname.to_s)
        @logger.level = Logger::DEBUG # Always log to the file at debug, formatter hides debug for non-verbose
        @logger.formatter = EY::Serverside::Shell::Formatter.new(@stdout, @stderr, start_time, @verbose)
      end

      def verbose?
        @verbose
      end

      # a nice info outputter that prepends spermy operators for some reason.
      def status(msg)
        if msg.respond_to?(:force_encoding)
          msg.force_encoding(Encoding::UTF_8)
        end
        info msg.gsub(BOL, STATUS_PREFIX)
      end

      def substatus(msg)
        debug msg.gsub(BOL, SUBSTATUS_PREFIX)
      end

      def fatal(msg)
        logger.fatal("FATAL: #{msg}")
      end

      def error(msg)
        logger.error("ERROR: #{msg}")
      end

      def warning(msg)
        logger.warn("WARNING: #{msg}")
      end
      alias warn warning

      def notice(msg)
        logger.warn(msg)
      end

      def info(msg)
        logger.info(msg)
      end

      def debug(msg)
        logger.debug(msg)
      end

      def unknown(msg)
        logger.unknown(msg)
      end

      # a debug outputter that displays a command being run
      # Formatis like this:
      #   $ cmd blah do \
      #   > something more
      #   > end
      def command_show(cmd)
        debug(cmd.gsub(BOL,CMD_CONTINUE).sub(CMD_CONTINUE, CMD_PREFIX))
      end

      def command_out(msg)
        debug(msg.gsub(BOL,CMD_INDENT))
      end

      def command_err(msg)
        unknown(msg.gsub(BOL,CMD_INDENT))
      end

      def logged_system(cmd, server = nil)
        EY::Serverside::Spawner.run(cmd, self, server)
      end

    end
  end
end
