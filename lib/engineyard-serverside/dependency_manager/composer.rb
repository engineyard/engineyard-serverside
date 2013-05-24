module EY
  module Serverside
    module DependencyManager
      class Composer < Base
        def detected?
           composer_lock? || composer_json?
        end

        def install
          if composer_available?
            shell.status "Installing composer packages (composer.#{lock_or_json} detected)"
            run "composer install --no-interaction --working-dir #{paths.active_release}"
          else
            shell.warning "composer.#{lock_or_json} detected but composer not available."
          end
        end

        def lock_or_json
          composer_lock? ? 'lock' : 'json'
        end

        def composer_lock?
          paths.composer_lock.exist?
        end

        def composer_json?
          paths.composer_json.exist?
        end

        def composer_available?
          begin
            run "command -v composer > /dev/null"
            return true
          rescue EY::Serverside::RemoteFailure
            return false
          end
        end
      end
    end
  end
end
