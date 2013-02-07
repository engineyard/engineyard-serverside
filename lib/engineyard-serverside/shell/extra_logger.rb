module EY
  module Serverside
    class Shell
      class ExtraLogger < Logger
        attr :extra_stdout
        attr :extra_stderr
        attr :verbose

        def extra(stdout, stderr, verbose)
          @extra_stdout = stdout
          @extra_stderr = stderr
          @verbose = verbose
        end

        def add(severity, message = nil, progname = nil, &block)
          severity ||= UNKNOWN
          progname ||= @progname
          if message.nil?
            if block_given?
              message = yield
            else
              message = progname
              progname = @progname
            end
          end
          msg = format_message(format_severity(severity), Time.now, progname, message)
          put_to_logdev(severity, msg)
          put_to_extra(severity, msg)
          true
        end

        def <<(msg)
          put_to_logdev(Logger::DEBUG, msg)
          put_to_extra(nil, msg)
        end

        def put_to_logdev(severity, msg)
          if @logdev.nil? or severity < @level
            return true
          end
          @logdev.write(msg)
        end

        def put_to_extra(severity, msg)
          case severity
          when Logger::DEBUG
            extra_output @extra_stdout, msg if @verbose
          when Logger::INFO
            # Need to differentiate info messages more when we're running in verbose mode
            extra_output @extra_stdout, (@verbose && msg.index('~>') ? "\n#{thor_shell.set_color(msg, :white, true)}" : msg)
          when Logger::WARN
            extra_output @extra_stderr, "\n#{thor_shell.set_color(msg, :yellow, true)}"
          when Logger::ERROR
            extra_output @extra_stderr, "\n#{thor_shell.set_color(msg, :red, true)}"
          else
            extra_output @extra_stderr, msg
          end
        end

        def extra_output output, msg
          if output
            output << msg
            begin
              output.fsync
            rescue
              nil
            end || output.flush
          end
        end

        private
        def thor_shell
          thor_shell ||= Thor::Shell::Color.new
        end

      end
    end
  end
end
