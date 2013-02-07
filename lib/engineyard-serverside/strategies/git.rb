module EY
  module Serverside
    module Strategies
      class Git
        attr_reader :shell, :opts

        def initialize(shell, opts)
          @shell = shell
          @opts = opts
        end

        def update_repository_cache
          unless fetch && checkout
            abort "*** [Error] Git could not checkout (#{to_checkout}) ***"
          end
        end

        def usable_repository?
          File.directory?(repository_cache) && `#{git} remote -v | grep origin`[remote_uri]
        end

        def fetch
          if usable_repository?
            run("#{git} fetch -q origin 2>&1")
          else
            FileUtils.rm_rf(repository_cache)
            run("git clone -q #{remote_uri} #{repository_cache} 2>&1")
          end
        end

        def checkout
          shell.status "Deploying revision #{short_log_message(to_checkout)}"
          in_repository_cache do
            (run("git checkout -f '#{to_checkout}'") ||
              run("git reset --hard '#{to_checkout}'")) &&
              run("git submodule sync") &&
              run("git submodule update --init") &&
              run("git clean -dfq")
          end
        end

        def to_checkout
          return @to_checkout if @opts_ref == opts[:ref]
          @opts_ref = opts[:ref]
          clean_local_branch(@opts_ref)
          @to_checkout = remote_branch?(@opts_ref) ? "origin/#{@opts_ref}" : @opts_ref
        end

        def clean_local_branch(ref)
          system("#{git} show-branch #{ref} > /dev/null 2>&1 && #{git} branch -D #{ref} > /dev/null 2>&1")
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

      private
        def run(cmd)
          shell.logged_system(cmd).success?
        end

        def in_repository_cache
          Dir.chdir(repository_cache) { yield }
        end

        def remote_uri
          opts[:repo]
        end

        def repository_cache
          opts[:repository_cache]
        end

        def git
          "git --git-dir #{repository_cache}/.git --work-tree #{repository_cache}"
        end

        def remote_branch?(ref)
          system("#{git} show-branch origin/#{ref} > /dev/null 2>&1")
        end
      end
    end
  end
end
