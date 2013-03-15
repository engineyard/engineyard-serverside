module EY
  module Serverside
    class Shell
      class CommandResult < Struct.new(:command, :success, :output, :server)
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
