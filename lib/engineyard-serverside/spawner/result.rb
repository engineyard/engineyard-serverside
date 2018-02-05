module EY
  module Serverside
    module Spawner
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
