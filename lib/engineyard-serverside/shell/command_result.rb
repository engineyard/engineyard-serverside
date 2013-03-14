module EY
  module Serverside
    class Shell
      class CommandResult < Struct.new(:command, :exitstatus, :output, :server)
        def success?
          exitstatus.to_i == 0
        end

        def inspect
          <<-EOM
$ #{command}
#{output}

($?: #{exitstatus})
          EOM
        end
      end
    end
  end
end
