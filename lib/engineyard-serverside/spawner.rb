require 'open3'
require 'engineyard-serverside/spawner'

module EY
  module Serverside
    class Spawner
      def self.run(cmd, shell, server = nil)
        s = new
        s.add(cmd, shell, server)
        s.run.first
      end

      def initialize
        @poll_period = 0
        @children = []
      end

      def add(cmd, shell, server = nil)
        @children << Child.new(cmd, shell, server)
      end

      def run
        @child_by_fd = {}
        @child_by_pid = {}

        @children.each do |child|
          pid, stdout_fd, stderr_fd = child.spawn
          @child_by_pid[pid] = child
          @child_by_fd[stdout_fd] = child
          @child_by_fd[stderr_fd] = child
        end

        while @child_by_pid.any?
          process
          wait
        end

        @children.map { |child| child.result }
      end

      protected

      def process
        read_fds = @child_by_pid.values.map {|child| child.ios }.flatten.compact
        ra, _, _ = IO.select(read_fds, [], [], @poll_period)
        process_readable(ra) if ra
      end

      def process_readable(ra)
        ra.each do |fd|
          child = @child_by_fd[fd]
          if !child
            raise "Select returned unknown fd: #{fd.inspect}"
          end

          begin
            if buf = fd.sysread(4096)
              child.append_to_buffer(fd, buf)
            else
              raise "sysread() returned nil"
            end
          rescue SystemCallError, EOFError => e
            @child_by_fd.delete(fd)
            child.close(fd)
          end
        end
      end

      def wait
        possible_children = true
        just_reaped = []
        while possible_children
          begin
            pid, status = Process::waitpid2(-1, Process::WNOHANG)
            if pid.nil?
              possible_children = false
            elsif child = @child_by_pid.delete(pid)
              child.finished status
              just_reaped << child
            elsif pid == -1
              # waitpid encountered an error (as defined in linux waitpid manpage)
              # apparently it can leak through ruby's waitpid abstraction
              raise "Fatal error encountered while waiting for a child process to exit. waitpid2 returned: [#{pid.inpsect}, #{status.inspect}].\nExpected one of children: #{@child_by_pid.keys.inspect}"
            else
              raise "Unknown pid returned from waitpid2 => #{pid.inpsect}, #{status.inspect}.\nExpected one of children: #{@child_by_pid.keys.inspect}"
            end
          rescue Errno::ECHILD
            possible_children = false
          end
        end
        # We may have waited on a child before reading all its output. Collect those missing bits. No blocking.
        if just_reaped.any?
          read_fds = just_reaped.map {|child| child.ios }.flatten.compact
          ra, _, _ = IO.select(read_fds, nil, nil, 0)
          process_readable(ra) if ra
        end
      end

      class Child
        attr_reader :stdout_fd, :stderr_fd

        def initialize(command, shell, server = nil)
          @command = command
          @shell = shell
          @server = server
          @output = ""
        end

        def spawn
          @shell.command_show @command
          #stdin, @stdout_fd, @stderr_fd, @waitthr = Open3.popen3(@cmd)
          #stdin.close

          stdin_rd, stdin_wr = IO.pipe
          @stdout_fd, stdout_wr = IO.pipe
          @stderr_fd, stderr_wr = IO.pipe

          @pid = fork do
            stdin_wr.close
            @stdout_fd.close
            @stderr_fd.close
            STDIN.reopen(stdin_rd)
            STDOUT.reopen(stdout_wr)
            STDERR.reopen(stderr_wr)
            Kernel.exec(@command)
            raise "Exec failed!"
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
            Result.new(@command, @status.success?, @output, @server)
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
            @shell.command_out data
            @output << data
          when @stderr_fd
            @shell.command_err data
            @output << data
          end
        end
      end

      class Result
        attr_reader :command, :success, :output, :server
        def initialize(command, success, output, server = nil)
          @command = command
          @success = success
          @output = output
          @server = server
        end

        alias success? success
        def inspect
          <<-EOM
$ #{success? ? "(success)" : "(failed)"} #{command}
#{output}
          EOM
        end
      end
    end
  end
end
