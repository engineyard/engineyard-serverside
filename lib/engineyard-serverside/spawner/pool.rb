require 'engineyard-serverside/spawner/child'
require 'engineyard-serverside/spawner/errors'

module EY
  module Serverside
    module Spawner
      class Pool
        POLL_PERIOD = 0.5

        def self.run(cmd, shell, server = nil)
          spawner = new
          spawner.add(cmd, shell, server)
          spawner.run.first
        end

        def add(cmd, shell, server = nil)
          children << Child.new(cmd, shell, server)
        end

        def run
          spawn_children
          wait_for_children
          results
        end

        private

        def process
          read_fds = children_by_pid.values.map {|child| child.ios }.flatten.compact
          ra, _, _ = IO.select(read_fds, [], [], POLL_PERIOD)
          process_readable(ra) if ra
        end

        def process_readable(ra)
          ra.each do |fd|
            child = children_by_fd[fd]
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
              children_by_fd.delete(fd)
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
              elsif child = children_by_pid.delete(pid)
                child.finished status
                just_reaped << child
              elsif pid == -1
                # waitpid encountered an error (as defined in linux waitpid manpage)
                # apparently it can leak through ruby's waitpid abstraction
                #raise "Fatal error encountered while waiting for a child process to exit. waitpid2 returned: [#{pid.inspect}, #{status.inspect}].\nExpected one of children: #{children_by_pid.keys.inspect}"
                raise WaitError.new(:waitpid2, pid, status, children_by_pid)
              else
                raise WaitError.new(:unknown, pid, status, children_by_pid)
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

        def children_by_pid
          @children_by_pid ||= {}
        end

        def children_by_fd
          @children_by_fd ||= {}
        end

        def children
          @children ||= []
        end

        def index_child(child, pid, stdout_fd, stderr_fd)
          children_by_pid[pid] = child
          children_by_fd[stdout_fd] = child
          children_by_fd[stderr_fd] = child
        end

        def results
          children.map { |child| child.result }
        end

        def wait_for_children
          while children_by_pid.any?
            process
            wait
          end
        end

        def spawn_children
          children.each do |child|
            pid, stdout_fd, stderr_fd = child.spawn
            index_child(child, pid, stdout_fd, stderr_fd)
          end
        end

      end
    end
  end
end
