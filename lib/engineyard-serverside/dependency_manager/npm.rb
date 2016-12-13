require 'engineyard-serverside/dependency_manager/base'

module EY
  module Serverside
    class DependencyManager
      class Npm < Base
        def detected?
          paths.package_json.exist?
        end

        def install
          shell.status "Installing npm packages (package.json detected)"
          run "mkdir -p #{paths.shared_node_modules} && ln -nfs #{paths.shared_node_modules} #{paths.active_node_modules}"
          run %{cd #{paths.active_release} && export GIT_SSH="#{ENV['GIT_SSH']}" && npm install #{npm_install_options.join(" ")}}
        end

        def npm_install_options
          options = []
          options += ['--production'] if npm_production?
          options
        end

        def npm_production?
          ENV['NODE_ENV'] == 'production'
        end
      end
    end
  end
end
