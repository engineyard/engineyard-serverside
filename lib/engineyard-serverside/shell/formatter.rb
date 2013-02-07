module EY
  module Serverside
    class Shell
      class Formatter
        def initialize(start_time)
          @start = start_time.to_i
        end

        def call(severity, time, _, message)
          build_message(severity, timestamp(time), message)
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
      end
    end
  end
end

