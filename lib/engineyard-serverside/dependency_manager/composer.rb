module EY
  module Serverside
    module DependencyManager
      class Composer < Base
        def detected?
           composer_lock? || composer_json?
        end

        def install
          if composer_available?
            if composer_json? and not composer_lock?
              shell.warning <<-WARN
composer.json found but composer.lock missing!
This may result in different versions of packages
being installed than what you tested with.

To fix this problem, commit your composer.lock to
the repository and redeploy.
              WARN
            end
            shell.status "Checking for composer updates..."
            composer_selfupdate
            shell.status "Installing composer packages (composer.#{lock_or_json} detected)"
            composer_install
          else
            raise EY::Serverside::RemoteFailure.new("composer.#{lock_or_json} detected but composer not available!")
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

        def composer_install
            run "composer install --no-interaction --working-dir #{paths.active_release}"
        end

        def composer_selfupdate
            run "composer self-update"
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
