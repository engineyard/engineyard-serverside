module EY
  module Serverside
    class Shell
      class Formatter
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
          if %w[WARN ERROR FATAL].include?(severity)
            prepend("#{stamp}!> ", "#{message}")
          elsif severity == "INFO"
            prepend(stamp, message)
          else
            prepend(' ' * stamp.size, message)
          end
        end

        def prepend(pre, str)
          str.gsub(/^/, pre).sub(/\n?\z/m,"\n")
        end

        def put_to_io(severity, msg)
          case severity
          when "DEBUG"
            if @verbose
              @stdout << msg
              @stdout.flush
            end
          when "INFO"
            # Need to differentiate info messages more when we're running in verbose mode
            @stdout << (@verbose && msg.index('~>') ? "\n#{thor_shell.set_color(msg, :white, true)}" : msg)
            @stdout.flush
          when "WARN"
            @stderr << "\n" << thor_shell.set_color(msg, :yellow, true)
            @stderr.flush
          when "ERROR"
            @stderr << "\n" << thor_shell.set_color(msg, :red, true)
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
            "+    %02ds  " % mod
          else
            "+%2dm %02ds  " % [div,mod]
          end
        end

        def thor_shell
          thor_shell ||= Thor::Shell::Color.new
        end
      end
    end
  end
end

