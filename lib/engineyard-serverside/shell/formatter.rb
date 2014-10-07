module EY
  module Serverside
    class Shell
      class Formatter
        FATAL = 'ERROR'.freeze
        ERROR = 'ERROR'.freeze
        WARN  = 'WARN'.freeze
        INFO  = 'INFO'.freeze
        DEBUG = 'DEBUG'.freeze
        IMPORTANT = [WARN, ERROR, FATAL].freeze

        SECONDS_FORMAT = '+    %02ds  '.freeze
        MINUTES_FORMAT = '+%2dm %02ds  '.freeze

        STATUS_PREFIX    = '~> '.freeze
        SUBSTATUS_PREFIX = ' ~ '.freeze
        IMPORTANT_PREFIX = '!> '.freeze

        NL = "\n".freeze

        def initialize(stdout, stderr, start_time, verbose)
          @stdout, @stderr = stdout, stderr
          @start = start_time.to_i
          @verbose = verbose
        end

        def call(severity, time, _, message)
          msg = build_message(severity, timestamp(time), message)
          put_to_io(severity, msg)
          msg
        end

        def build_message(severity, stamp, message)
          if IMPORTANT.include?(severity)
            prepend("#{stamp}#{IMPORTANT_PREFIX}", message)
          elsif INFO == severity
            prepend(stamp, message)
          else
            prepend(stamp, message)
          end
        end

        def prepend(pre, str)
          str.gsub(/^/, pre).sub(/\n?\z/m,NL)
        end

        def put_to_io(severity, msg)
          case severity
          when DEBUG
            if @verbose
              @stdout << msg
              @stdout.flush
            end
          when INFO
            # Need to differentiate info messages more when we're running in verbose mode
            if @verbose && msg.index(STATUS_PREFIX)
              @stdout.puts
              @stdout << thor_shell.set_color(msg, :white, true)
            else
              @stdout << msg
            end
            @stdout.flush
          when WARN
            @stderr.puts
            @stderr << thor_shell.set_color(msg, :yellow, true)
            @stderr.flush
          when ERROR
            @stderr.puts
            @stderr << thor_shell.set_color(msg, :red, true)
            @stderr.flush
          else
            @stderr << msg
            @stderr.flush
          end
        end

        def timestamp(datetime)
          diff = datetime.to_i - @start
          diff = 0 if diff < 0
          div, mod = diff.divmod(60)
          if div.zero?
            SECONDS_FORMAT % mod
          else
            MINUTES_FORMAT % [div,mod]
          end
        end

        def thor_shell
          thor_shell ||= Thor::Shell::Color.new
        end
      end
    end
  end
end

