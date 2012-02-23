module EY
  module Serverside
    class Shell
      # Compatibility with old LoggedOutput where the module was included into the class.
      module Helpers
        def verbose?
          shell.verbose?
        end

        def warning(*a)
          shell.warning(*a)
        end

        def info(*a)
          shell.info(*a)
        end

        def debug(*a)
          shell.debug(*a)
        end

        def logged_system(*a)
          shell.logged_system(*a)
        end
      end
    end
  end
end

