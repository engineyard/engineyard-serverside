require 'railway'
require 'runner'

module EY
  module Serverside
    module Slug

      class Restarter
        include Railway
        include Runner

        step :restart_remote_apps
        step :restart_local

        attr_reader :config, :shell, :servers

        def self.restart(data = {})
          new(data[:config], data[:shell], data[:servers]).call(data)
        end

        def initialize(config, shell, servers)
          @config = config
          @shell = shell
          @servers = servers
        end

        private
        def restart_remote_apps(data = {})
          restarted = []

          remote_apps.each do |remote|
            if run_and_success?(remote_command(remote, data))
              restarted.push(remote)
            else
              return Failure(
                data.merge(
                  :restarted => restarted,
                  :error => "Could not restart #{data[:release_name]} on #{remote.hostname}"
                )
              )
            end
          end

          Success(data.merge(:restarted => restarted))
        end

        def restart_local(data = {})
          unless run_and_success?(restart_command(data))
            return Failure(data.merge(:error => "Could not restart #{data[:release_name]} on the app master"))
          end

          data[:restarted].push(master)

          Success(data)
        end

        def remotes
          server_array.reject {|server|
            master?(server)
          }
        end

        def remote_apps
          remotes.select {|server| server.role == :app}
        end

        def master?(server)
          server == master
        end

        def util?(server)
          server.role == :util
        end

        def master
          @master ||= server_array.find {|server|
            master_roles.include?(server.role)
          }
        end

        def master_roles
          [:app_master, :solo]
        end

        def server_array
          @server_array ||= servers.to_a
        end

        def remote_command(remote, data)
          "ssh -i #{internal_key} #{remote.user}@#{remote.hostname} '#{restart_command(data)}'"
        end

        def restart_command(data)
          %{LANG="en_US.UTF-8" /engineyard/bin/app_#{data[:app_name]} deploy}
        end

        def internal_key
          config.paths.internal_key
        end
      end
    end
  end
end
