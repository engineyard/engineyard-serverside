require 'pathname'
require 'uri'

module EY
  module Serverside
    module Strategies
      class Package
        attr_reader :shell, :opts, :uri, :filename, :source_cache, :ref

        def initialize(shell, opts)
          @shell = shell
          @opts = opts
          @ref = @opts[:ref]
          @uri = URI.parse(@opts[:uri])
          @filename = File.basename(@uri.path)
          @source_cache = Pathname.new(@opts[:repository_cache])
        end

        # Expand the correct file into the source_cache location
        def update_repository_cache
          clean_cache
          fetch
          unarchive
        end

        def clean_cache
          run "rm -rf #{source_cache} && mkdir -p #{source_cache}"
        end

        def fetch
          #if uri.scheme == 'file' || uri.relative
          #  "rsync -aq --delete #{uri.path} #{source_cache}"
          #else
            run "curl -sSO --user-agent 'EngineYardDeploy/#{EY::Serverside::VERSION}' '#{uri}'"
          #end
        end

        def unarchive
          case File.extname(filename)
          when 'zip','war'
            run "cd #{source_cache} && unzip #{filename} && rm #{filename}"
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
