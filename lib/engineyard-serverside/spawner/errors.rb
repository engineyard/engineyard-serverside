module EY
  module Serverside
    module Spawner
      class WaitError < Exception
        def initialize(problem, pid, status, children_by_pid)
          formatted_pid = pid.inspect
          formatted_status = status.inspect
          formatted_children = children_by_pid.keys.inspect

          message = case problem
          when :waitpid2
            "Fatal error encountered while waiting for a child process to exit. waidpid2 returned: [#{formatted_pid}, #{formatted_status}]."
          when :unknown
            "Unknown pid returned from waitpid2 => #{formatted_pid}, #{formatted_status}."
          end

          super(message + "\nExpected one of children: #{formatted_children}")
        end
      end

    end
  end
end
