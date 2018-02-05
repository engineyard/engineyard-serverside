require 'engineyard-serverside/spawner/result'

module EY
  module Serverside
    module Spawner
      class Child
        attr_reader :stdout_fd, :stderr_fd

        def initialize(command, shell, server = nil)
          @command = command
          @shell = shell
          @server = server
        end

        def spawn
          shell.command_show @command
          #stdin, @stdout_fd, @stderr_fd, @waitthr = Open3.popen3(@cmd)
          #stdin.close

          stdin_rd, stdin_wr = IO.pipe
          @stdout_fd, stdout_wr = IO.pipe
          @stderr_fd, stderr_wr = IO.pipe

          @pid = fork do
            fork_this(stdin_rd, stdin_wr, stdout_wr, stderr_wr)
          end

          stdin_rd.close
          stdin_wr.close
          stdout_wr.close
          stderr_wr.close

          [@pid, @stdout_fd, @stderr_fd]
        end

        def ios
          [@stdout_fd, @stderr_fd].compact
        end

        def finished(status)
          @status = status
        end

        def result
          if @status
            Result.new(@command, @status.success?, output, @server)
          else
            raise "No result from unfinished child process"
          end
        end

        def close(fd)
          case fd
          when @stdout_fd then @stdout_fd = nil
          when @stderr_fd then @stderr_fd = nil
          end
          fd.close rescue true
        end

        def append_to_buffer(fd,data)
          case fd
          when @stdout_fd
            shell.command_out data
            output << data
          when @stderr_fd
            shell.command_err data
            output << data
          end
        end

        private
        def output
          @output ||= ""
        end

        def shell
          @shell
        end

        def fork_this(stdin_rd, stdin_wr, stdout_wr, stderr_wr)
          stdin_wr.close
          @stdout_fd.close
          @stderr_fd.close
          STDIN.reopen(stdin_rd)
          STDOUT.reopen(stdout_wr)
          STDERR.reopen(stderr_wr)
          Kernel.exec(@command)
          raise "Exec failed!"
        end
      end
    end
  end
end
