module EY
  module Strategies
    class Git
      module Helpers
        def update_repository_cache
          klass = Module.nesting[1]

          strategy = klass.new(
            :repository_cache => repository_cache,
            :repo => repo,
            :branch => branch
          )

          strategy.fetch
          strategy.checkout
        end
      end

      attr_reader :opts

      def initialize(opts)
        @opts = opts
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
    end
  end
end
