require 'pathname'

module EY
  module Serverside
    module Strategies
      class Git
        attr_reader :shell, :opts, :remote_uri, :repository_cache

        def initialize(shell, opts)
          @shell = shell
          @opts = opts
          unless @opts[:ref] && @opts[:remote_uri] && @opts[:repository_cache]
            raise ArgumentError, "Missing required keys. (:ref, :remote_uri, and :repository_cache are required)"
          end
          @ref = opts[:ref]
          @remote_uri = @opts[:remote_uri]
          @repository_cache = Pathname.new(@opts[:repository_cache])
        end

        def update_repository_cache
          unless fetch && checkout
            abort "*** [Error] Git could not checkout (#{to_checkout}) ***"
          end
        end

        def usable_repository?
          repository_cache.directory? && `#{git} remote -v | grep origin`.include?(remote_uri)
        end

        def fetch
          if usable_repository?
            run("#{git} fetch -q origin 2>&1")
          else
            run("rm -rf #{repository_cache} && git clone -q #{remote_uri} #{repository_cache} 2>&1")
          end
        end

        def checkout
          shell.status "Deploying revision #{short_log_message(to_checkout)}"
          q = opts[:verbose] ? '' : '-q'
          in_repository_cache do
            (run("git checkout -f #{q} '#{to_checkout}'") ||
              run("git reset --hard #{q} '#{to_checkout}'")) &&
              run("git submodule sync") &&
              run("git submodule update --init") &&
              run("git clean -dfq")
          end
        end

        def to_checkout
          @to_checkout ||= begin
                             clean_local_branch(@ref)
                             remote_branch?(@ref) ? "origin/#{@ref}" : @ref
                           end
        end

        def clean_local_branch(given_ref)
          system("#{git} show-branch #{given_ref} > /dev/null 2>&1 && #{git} branch -D #{given_ref} > /dev/null 2>&1")
        end

        def gc_repository_cache
          shell.status "Garbage collecting cached git repository to reduce disk usage."
          run("#{git} gc")
        end

        def create_revision_file_command(dir)
          %Q{#{git} show --pretty=format:"%H" | head -1 > "#{dir}/REVISION"}
        end

        def short_log_message(rev)
          `#{git} log --pretty=oneline --abbrev-commit -n 1 '#{rev}'`.strip
        end

        # git diff --exit-code returns
        #   0 when nothing has changed
        #   1 when there are changes
        #
        # Thes method returns true when nothing has changed, fales otherwise
        def same?(previous_revision, active_revision, paths = nil)
          run("#{git} diff '#{previous_revision}'..'#{active_revision}' --exit-code --name-only -- #{Array(paths).join(' ')} >/dev/null 2>&1")
        end

      private
        def run(cmd)
          EY::Serverside::Spawner.run(cmd, shell, nil).success?
        end

        def in_repository_cache
          Dir.chdir(repository_cache) { yield }
        end

        def git
          "git --git-dir #{repository_cache}/.git --work-tree #{repository_cache}"
        end

        def remote_branch?(given_ref)
          system("#{git} show-branch origin/#{given_ref} > /dev/null 2>&1")
        end
      end
    end
  end
end
