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
            prepend("#{stamp}!> ", "#{severity_name(severity)}#{message}")
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
          if severity == "DEBUG"
            if @verbose
              @stdout << msg
            end
          elsif severity == "INFO"
            # Need to differentiate info messages more when we're running in verbose mode
            @stdout << (@verbose ? "\n\e[1m#{msg}\e[0m" : msg)
            @stdout.flush
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

        def severity_name(severity)
          if %w[INFO DEBUG ANY].include?(severity)
            ""
          elsif severity =='WARN'
            "WARNING: "
          else
            "#{severity}: "
          end
        end
      end
    end
  end
end

