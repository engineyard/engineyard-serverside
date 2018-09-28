require 'railway'
require 'runner'

module EY
  module Serverside
    module Slug
      class Distributor
        include Railway
        include Runner

        step :find_remotes
        step :distribute_to_remotes

        def self.distribute(data = {})
          new(data[:config], data[:shell], data[:servers]).call(data)
        end

        attr_reader :config, :shell, :servers

        def initialize(config, shell, servers)
          @config = config
          @shell = shell
          @servers = servers
        end

        private
        def find_remotes(input = {})
          remotes = servers.
            to_a.
            reject {|server| server.role.to_sym == :app_master}

          Success(input.merge(:remotes => remotes))
        end

        def distribute_to_remotes(input = {})
          remotes = input[:remotes]
          releases_path = "/data/#{input[:app_name]}/releases"
          package = "#{releases_path}/#{input[:release_name]}.tgz"
          internal_key = config.paths.internal_key

          remotes.each do |remote|
            cmd = "scp -i #{internal_key} #{package} #{remote.user}@#{remote.hostname}:#{releases_path}"

            unless run_and_success?(cmd)
              return Failure(
                input.merge(
                  :error => "Could not copy #{package} to #{remote.hostname}"
                )
              )
            end
          end

          Success(input)
        end
      end
    end
  end
end
