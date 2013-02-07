
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
        File.expand_path("../../../bin/#{gem_name}", __FILE__)
      end

    end
  end
end
