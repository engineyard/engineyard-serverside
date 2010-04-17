module EY
  module Strategies
    class Git
      module Helpers
        def update_repository_cache
          klass = Module.nesting[1]

          strategy = klass.new(
            :repository_cache => c.repository_cache,
            :app => c.app,
            :repo => c.repo,
            :branch => c.branch
          )

          strategy.fetch
          strategy.checkout
        end
      end

      attr_reader :opts

      def initialize(opts)
        @opts = opts
        set_up_git_ssh(@opts[:app])
      end

      def fetch
        if File.directory?(File.join(opts[:repository_cache], ".git"))
          `#{git} fetch origin`
        else
          `git clone #{opts[:repo]} #{opts[:repository_cache]}`
        end
      end

      def checkout
        `#{git} reset --hard origin/#{opts[:branch]}`
      end

    private
      def git
        "git --git-dir #{opts[:repository_cache]}/.git --work-tree #{opts[:repository_cache]}"
      end

      def set_up_git_ssh(app)
        # hold references to the tempfiles so they don't get finalized
        # unexpectedly; tempfile finalization unlinks the files
        @git_ssh = Tempfile.open("git-ssh")
        @config = Tempfile.open("git-ssh-config")

        @config.write "StrictHostKeyChecking no\n"
        @config.write "CheckHostIP no\n"
        @config.write "PasswordAuthentication no\n"
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
