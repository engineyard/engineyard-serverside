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
          in_source_cache do
            fetch
            unarchive
          end
        end

        def clean_cache
          run "rm -rf #{source_cache} && mkdir -p #{source_cache}"
        end

        def fetch
          run "curl --location --silent --show-error -O --user-agent 'EngineYardDeploy/#{EY::Serverside::VERSION}' '#{uri}'"
        end

        def unarchive
          ext = File.extname(filename)
          case ext
          when '.zip', '.war'
            run "unzip #{filename} && rm #{filename}"
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

        def in_source_cache(&block)
          return unless block
          Dir.chdir(@source_cache) { block.call }
        end

      end
    end
  end
end
