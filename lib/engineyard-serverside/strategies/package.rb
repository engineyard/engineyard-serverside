require 'pathname'

module EY
  module Serverside
    module Strategies
      class Package
        attr_reader :shell, :opts, :remote_uri, :source_cache, :ref

        def initialize(shell, opts)
          @shell = shell
          @opts = opts
          @ref = @opts[:ref]
          @remote_uri = @opts[:remote_uri]
          @source_cache = Pathname.new(@opts[:repository_cache])
        end

        # Expand the correct file into the source_cache location
        def update_repository_cache
          run "rm -rf #{source_cache} && mkdir -p #{source_cache} && #{fetch}"
        end

        def fetch
          uri = URI.parse(remote_uri)
          if uri.scheme == 'file' || uri.relative
            "rsync -aq --delete #{uri.path} #{source_cache}"
          else
            "cd #{source_cache} && curl -sSO --user-agent 'EngineYardDeploy/#{EY::Serverside::VERSION}' '#{uri}'"
          end
        end

        # Perform any cleanup
        def gc_repository_cache
          # If files are uploaded to the server, we should clean them up here probably.
        end

        def create_revision_file_command(dir)
          %Q{echo '#{ref.gsub(/'/,"'\\''")}' > "#{dir}/REVISION"}
        end

        def short_log_message(rev)
          rev
        end

        def same?(previous_revision, active_revision, paths = nil)
          previous_revision == active_revision
        end

      private
        def run(cmd)
          shell.logged_system(cmd).success?
        end

      end
    end
  end
end
