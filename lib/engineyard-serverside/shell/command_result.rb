module EY
  module Serverside
    class Shell
      class CommandResult < Struct.new(:command, :exitstatus, :output)
        def success?
          exitstatus.zero?
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
