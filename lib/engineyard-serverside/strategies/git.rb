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
            shell.logged_system("#{git} fetch -q origin 2>&1")
          else
            FileUtils.rm_rf(repository_cache)
            shell.logged_system("git clone -q #{remote_uri} #{repository_cache} 2>&1")
          end
        end

        def checkout
          shell.status "Deploying revision #{short_log_message(to_checkout)}"
          in_repository_cache do
            (shell.logged_system("git checkout -q '#{to_checkout}'") ||
              shell.logged_system("git reset -q --hard '#{to_checkout}'")) &&
              shell.logged_system("git submodule sync") &&
              shell.logged_system("git submodule update --init") &&
              shell.logged_system("git clean -dfq")
          end
        end

        def to_checkout
          return @to_checkout if @opts_ref == opts[:ref]
          @opts_ref = opts[:ref]
          @to_checkout = branch?(@opts_ref) ? "origin/#{@opts_ref}" : @opts_ref
        end

        def create_revision_file_command(dir)
          %Q{#{git} show --pretty=format:"%H" | head -1 > "#{dir}/REVISION"}
        end

        def short_log_message(rev)
          `#{git} log --pretty=oneline --abbrev-commit -n 1 '#{rev}'`.strip
        end

      private
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

        def branch?(ref)
          system("#{git} show-branch origin/#{ref} > /dev/null 2>&1")
        end
      end
    end
  end
end
