require 'ey-deploy/logged_output'

module EY
  module Strategies
    class Git
      module Helpers
        def update_repository_cache
          strategy.fetch
          unless strategy.checkout
            abort "*** [Error] Git could not checkout (#{strategy.to_checkout}) ***"
          end
        end

        def create_revision_file
          strategy.create_revision_file(c.release_path)
        end

        def short_log_message(revision)
          strategy.short_log_message(revision)
        end

        def strategy
          klass = Module.nesting[1]
          # Use [] to access attributes instead of calling methods so
          # that we get nils instead of NoMethodError.
          #
          # Rollback doesn't know about the repository location (nor
          # should it need to), but it would like to use #short_log_message.
          klass.new(
            :repository_cache => c[:repository_cache],
            :app => c[:app],
            :repo => c[:repo],
            :ref => c[:branch]
          )
        end
      end

      include LoggedOutput

      attr_reader :opts

      def initialize(opts)
        @opts = opts
        set_up_git_ssh(@opts[:app])
      end

      def usable_repository?
        File.directory?(opts[:repository_cache]) && `#{git} remote -v | grep origin`[opts[:repo]]
      end

      def fetch
        if usable_repository?
          logged_system("#{git} fetch -q origin")
        else
          FileUtils.rm_rf(opts[:repository_cache])
          logged_system("git clone -q #{opts[:repo]} #{opts[:repository_cache]}")
        end
      end

      def checkout
        info "~> Deploying revision #{short_log_message(to_checkout)}"
        logged_system("#{git} checkout -q '#{to_checkout}'") || logged_system("#{git} reset -q --hard '#{to_checkout}'")
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

      def create_revision_file(dir)
        `#{git} show --pretty=format:"%H" | head -1 > "#{dir}/REVISION"`
      end

      def short_log_message(rev)
        `#{git} log --pretty=oneline --abbrev-commit '#{rev}^..#{rev}'`.strip
      end

    private
      def git
        "git --git-dir #{opts[:repository_cache]}/.git --work-tree #{opts[:repository_cache]}"
      end

      def branch?(ref)
        `#{git} branch -r`.map { |x| x.strip }.include?("origin/#{ref}")
      end

      def set_up_git_ssh(app)
        # hold references to the tempfiles so they don't get finalized
        # unexpectedly; tempfile finalization unlinks the files
        @git_ssh = Tempfile.open("git-ssh")
        @config = Tempfile.open("git-ssh-config")

        @config.write "StrictHostKeyChecking no\n"
        @config.write "CheckHostIP no\n"
        @config.write "PasswordAuthentication no\n"
        @config.write "LogLevel DEBUG\n"
        @config.write "IdentityFile ~/.ssh/#{app}-deploy-key\n"
        @config.chmod(0600)
        @config.close

        @git_ssh.write "#!/bin/sh\n"
        @git_ssh.write "unset SSH_AUTH_SOCK\n"
        @git_ssh.write "ssh -F \"#{@config.path}\" $*\n"
        @git_ssh.chmod(0700)
        # NB: this file _must_ be closed before git looks at it.
        #
        # Linux won't let you execve a file that's open for writing,
        # so if this file stays open, then git will complain about
        # being unable to exec it and will exit with a message like
        #
        # fatal: exec /tmp/git-ssh20100417-21417-d040rm-0 failed.
        @git_ssh.close

        ENV['GIT_SSH'] = @git_ssh.path
      end
    end
  end
end
