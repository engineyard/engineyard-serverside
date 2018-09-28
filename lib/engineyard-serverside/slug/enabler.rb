require 'railway'
require 'runner'

module EY
  module Serverside
    module Slug

      class Enabler
        include Railway
        include Runner

        step :enable_remotes
        step :enable_local

        attr_reader :config, :shell, :servers

        def initialize(config, shell, servers)
          @config = config
          @shell = shell
          @servers = servers
        end

        private
        def enable_remotes(data)
          enabled = []

          remotes.each do |remote|
            if run_and_success?(remote_command(remote, data))
              enabled.push(remote)
            else
              return Failure(
                data.merge(
                  :enabled => enabled,
                  :error => "Could not enable #{data[:release_name]} on #{remote.hostname}"
                )
              )
            end
          end

          Success(data.merge(:enabled => enabled))
        end

        def enable_local(data = {})
          unless run_and_success?(local_command(data))
            return Failure(data.merge(:error => "Could not enable #{data[:release_name]} on the app master"))
          end

          data[:enabled].push(servers.first {|server| server.role == :app_master || server.role == :solo})

          Success(data)
        end

        def remotes
          servers.reject {|server| server.role == :app_master}
        end

        def remote_command(remote, data)
          "ssh -i #{config.paths.internal_key} #{remote.user}@#{remote.hostname} '#{create_release(data)} && #{unarchive(data)} && #{link_current(data)}'"
        end

        def local_command(data)
          "#{unarchive(data)} && #{link_current(data)}"
        end

        def create_release(data)
          "mkdir -p #{release_path(data)}"
        end

        def unarchive(data)
          "tar -C #{release_path(data)} -z -x -f #{package(data)}"
        end

        def link_current(data)
          "ln -nsf #{release_path(data)} #{current_path(data)}"
        end

        def package(data)
          "#{release_path(data)}.tgz"
        end

        def release_path(data)
          "#{all_releases(data)}/#{data[:release_name]}"
        end

        def all_releases(data)
          "#{app_path(data)}/releases"
        end

        def current_path(data)
          "#{app_path(data)}/current"
        end

        def app_path(data)
          "/data/#{data[:app_name]}"
        end
      end

    end
  end
end
