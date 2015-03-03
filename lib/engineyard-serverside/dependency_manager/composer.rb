require 'engineyard-serverside/dependency_manager/base'

module EY
  module Serverside
    class DependencyManager
      class Composer < Base
        def detected?
          composer_lock? || composer_json?
        end

        def check
          unless composer_available?
            raise EY::Serverside::RemoteFailure.new("composer.#{lock_or_json} detected but composer not available!")
          end

          if composer_json? && !composer_lock?
            shell.warning <<-WARN
composer.json found but composer.lock missing!
This may result in different versions of packages
being installed than what you tested with.

To fix this problem, commit your composer.lock to the repository and redeploy.
            WARN
          end
        end

        def install
          shell.status "Checking for composer updates..."
          composer_selfupdate
          shell.status "Installing composer packages (composer.#{lock_or_json} detected)"
          composer_install
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
          run %{export GIT_SSH="#{ENV['GIT_SSH']}" && composer install --no-interaction --no-dev --optimize-autoloader --working-dir #{paths.active_release}}
        end

        def composer_selfupdate
          run "command -v composer | xargs -I composer find composer -user #{config.user} -exec {} self-update \\;"
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
