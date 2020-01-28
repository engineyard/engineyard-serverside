
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
        gem_bin_path = File.join(Gem.default_bindir, 'gem')
        if File.exists?("/usr/local/ey_resin/bin/ruby")
          "/usr/local/ey_resin/bin/ruby -rubygems #{gem_bin_path}"
        else
          gem_bin_path
        end
      end

      def binary
        File.expand_path("../../../bin/#{gem_name}", __FILE__)
      end

      def hook_executor
        binary + "-execute-hook"
      end

      def service_hook_executor
        binary + "-execute-service-hook"
      end
    end
  end
end
