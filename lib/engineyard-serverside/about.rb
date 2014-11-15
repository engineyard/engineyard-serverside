
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

      def bin_path
        File.expand_path("../../../bin", __FILE__)
      end

      def binary
        File.join(bin_path, gem_name)
      end

      def hook_executor
        binary + "-execute-hook"
      end
    end
  end
end
