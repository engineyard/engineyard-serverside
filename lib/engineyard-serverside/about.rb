
module EY
  module Serverside
    module About
      extend self

      def gem_name
        "engineyard-serverside"
      end

      def version
        EY::Serverside::VERSION
      end

      def name_with_version
        "#{gem_name} #{version}"
      end

      def gem_filename
        "#{gem_name}-#{version}.gem"
      end

      def gem_file
        File.join(Gem.dir, 'cache', gem_filename)
      end

      def gem_binary
        File.join(Gem.default_bindir, 'gem')
      end

      def binary
        resin_path = "/usr/local/ey_resin/ruby/bin/engineyard-serverside"
        if File.exists?(resin_path)
          resin_path
        else
          #gem relative path causes deploy hook failures if gem version mismatches with other app servers
          File.expand_path("../../../bin/#{gem_name}", __FILE__)
        end
      end

      def hook_executor
        binary + "-execute-hook"
      end
    end
  end
end
