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

          def release_manager
            if paths.mix_ex.match('exrm')
              exrm_release
            elsif paths.mix_ex.match('distillery')
              distillery_release
            else
              shell.status "Please install distillery or exrm in your project"
            end
          end

          #Commands for exrm release process
          def exrm_release
            run %{cd #{paths.active_release} && #{elixir_compile} && mix release && rsync -avHl #{paths.active_release}/rel/ #{paths.elixir_rel}}
          end

          #Commands for distillery release process
          def distillery_release
            run %{cd #{paths.active_release} && #{elixir_compile} && mix release.init && mix release && rsync -avHl #{paths.active_release}/_bundle/ #{paths.elixir_rel}}
          end

          #Eventually add to ey.yml for either phoenix or mix compile
          def elixir_compile
            "mix phoenix.digest"
          end


          def install
            shell.status "Installing  packages (mix.ex detected)"
            run "mkdir -p #{paths.elixir_deps} && ln -nfs #{paths.elixir_deps} #{paths.active_elixir_deps}"
            run %{mkdir -p #{paths.active_release}/priv/static}
            run %{ln -nfs #{paths.shared_config}/prod.secret.exs #{paths.active_release_config}/prod.secret.exs}
            run %{ln -nfs #{paths.shared_config}/customer.secret.exs #{paths.active_release_config}/customer.secret.exs}
            run %{cd #{paths.active_release} && export GIT_SSH="#{ENV['GIT_SSH']}" && mix deps.get #{mix_install_options.join(" ")}}
            release_manager
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
  end
