require 'railway'
require 'runner'

module EY
  module Serverside
    module Slug

      class Finalizer
        include Railway
        include Runner

        step :finalize_remotes
        step :finalize_local

        attr_reader :config, :shell, :servers

        def initialize(config, shell, servers)
          @config = config
          @shell = shell
          @servers = servers
        end

        private
        def finalize_remotes(data)
          finalized = []

          remotes.each do |remote|
            if run_and_success?(remote_command(remote, data))
              finalized.push(remote)
            else
              return Failure(
                data.merge(
                  :finalized => finalized,
                  :error => "Could not finalize #{data[:release_name]} on #{remote.hostname}"
                )
              )
            end
          end

          Success(data.merge(:finalized => finalized))
        end

        def finalize_local(data = {})
          unless run_and_success?(finalize_command(data))
            return Failure(data.merge(:error => "Could not finalize #{data[:release_name]} on the app master"))
          end

          data[:finalized].push(servers.first {|server| server.role == :app_master || server.role == :solo})

          Success(data)
        end

        def remotes
          servers.reject {|server| server.role == :app_master}
        end

        def remote_command(remote, data)
          "ssh -i #{config.paths.internal_key} #{remote.user}@#{remote.hostname} '#{finalize_command(data)}'"
        end

        def finalize_command(data)
          "rm -rf #{old_release_path(data)}"
        end

        def old_release_path(data)
          "#{all_releases(data)}/#{data[:current_release_name]}"
        end

        def all_releases(data)
          "#{app_path(data)}/releases"
        end

        def app_path(data)
          "/data/#{data[:app_name]}"
        end
      end

    end
  end
end
