require 'engineyard-serverside/dependency_manager/base'

module EY
  module Serverside
    class DependencyManager
      class Mix < Base

          def detected?
            paths.mix_ex.exist?
          end

          def lockfile_detected?
            paths.mix_lock.exist?
          end

          #Eventually added to
          elixir_compile = "mix phoenix.digest"

          def install
            shell.status "Installing  packages (mix.ex detected)"
            run "mkdir -p #{paths.elixir_deps} && ln -nfs #{paths.elixir_deps} #{paths.active_elixir_deps}"
            run %{ln -nfs #{paths.shared_config}/prod.secret.exs #{paths.active_release_config}/prod.secret.exs}
            run %{ln -nfs #{paths.shared_config}/customer.secret.exs #{paths.active_release_config}/customer.secret.exs}
            run %{cd #{paths.active_release} && export GIT_SSH="#{ENV['GIT_SSH']}" && mix deps.get #{mix_install_options.join(" ")}}
            run %{cd #{paths.active_release} && #{elixir_compile} && rsync -avHl #{paths.active_release}/rel #{paths.elixir_rel}}
          end

          def mix_install_options
            options = []
            options += ['--prod'] if mix_production?
            options
          end


          def mix_production?
            ENV['MIX_ENV'] == 'prod'
          end

        end
      end
    end
