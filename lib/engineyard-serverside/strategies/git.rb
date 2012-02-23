module EY
  module Serverside
    module Strategies
      class Git
        module Helpers
          def update_repository_cache
            unless strategy.fetch && strategy.checkout
              abort "*** [Error] Git could not checkout (#{strategy.to_checkout}) ***"
            end
          end

          def create_revision_file_command
            strategy.create_revision_file_command(c.release_path)
          end

          def short_log_message(revision)
            strategy.short_log_message(revision)
          end

          def strategy
            # Ensure the git ssh config is up to date with the current app.
            ENV['GIT_SSH'] = ssh_executable
            klass = Module.nesting[1]
            # Use [] to access attributes instead of calling methods so
            # that we get nils instead of NoMethodError.
            #
            # Rollback doesn't know about the repository location (nor
            # should it need to), but it would like to use #short_log_message.
            klass.new(shell,
              :repository_cache => c[:repository_cache],
              :app => c[:app],
              :repo => c[:repo],
              :ref => c[:branch]
            )
          end
        end

        attr_reader :shell, :opts

        def initialize(shell, opts)
          @shell = shell
          @opts = opts
        end

        def usable_repository?
          File.directory?(opts[:repository_cache]) && `#{git} remote -v | grep origin`[opts[:repo]]
        end

        def fetch
          if usable_repository?
            shell.logged_system("#{git} fetch -q origin 2>&1")
          else
            FileUtils.rm_rf(opts[:repository_cache])
            shell.logged_system("git clone -q #{opts[:repo]} #{opts[:repository_cache]} 2>&1")
          end
        end

        def checkout
          shell.status "Deploying revision #{short_log_message(to_checkout)}"
          in_git_work_tree do
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
          @to_checkout = if branch?(opts[:ref])
            "origin/#{opts[:ref]}"
          else
            opts[:ref]
          end
        end

        def create_revision_file_command(dir)
          %Q{#{git} show --pretty=format:"%H" | head -1 > "#{dir}/REVISION"}
        end

        def short_log_message(rev)
          `#{git} log --pretty=oneline --abbrev-commit -n 1 '#{rev}'`.strip
        end

      private
        def in_git_work_tree
          Dir.chdir(git_work_tree) { yield }
        end

        def git_work_tree
          opts[:repository_cache]
        end

        def git
          "git --git-dir #{git_work_tree}/.git --work-tree #{git_work_tree}"
        end

        def branch?(ref)
          remote_branches = `#{git} branch -r`
          remote_branches.each_line do |line|
            return true if line.include?("origin/#{ref}")
          end
          false
        end
      end
    end
  end
end
