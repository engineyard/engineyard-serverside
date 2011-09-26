require 'yaml'
module EY
  module Serverside
    class LockfileParser
      DEFAULT = "1.0.10"

      def self.default_version
        DEFAULT
      end

      attr_reader :bundler_version, :lockfile_version

      def initialize(lockfile_contents)
        @contents = lockfile_contents
        parse
      end

      def any_database_adapter?
        %w[mysql2 mysql do_mysql pg do_postgres].any? do |gem|
          @contents.index(/^\s+#{gem}\s\([^\)]+\)$/)
        end
      end

      def parse
        parse_from_metadata ||
          parse_from_dependencies ||
          raise("Malformed or pre bundler-1.0.0 Gemfile.lock: #{@contents[0,50]}...")
      end

      def slice_section(header)
        if start = @contents.index(/^#{header}/)
          finish = @contents.index(/(^\S|\Z)/, start + header.length)
          @contents.slice(start..finish)
        else
          ""
        end
      end

      def parse_from_metadata
        section = slice_section('METADATA')

        if section.empty?
          return nil
        end

        result = section.scan(/^\s*version:\s*(.*)$/).first
        @lockfile_version = :bundler10
        @bundler_version = result ? result.first : DEFAULT
      end

      def parse_from_dependencies
        section = slice_section('DEPENDENCIES')

        if section.empty?
          return nil
        end

        result = scan_bundler(section)
        bundler_version = result ? result.last : nil
        version_qualifier = result ? result.first : nil
        @lockfile_version = :bundler10
        @bundler_version = fetch_version(bundler_version, version_qualifier)
      end

      def fetch_version(bundler_version, version_qualifier)
        return bundler_version || DEFAULT unless version_qualifier

        case version_qualifier
        when '='
          bundler_version
        when '>='
          Gem::Version.new(bundler_version) > Gem::Version.new(DEFAULT) ? bundler_version : DEFAULT
        when '~>'
          bundler_gem_version = Gem::Version.new(bundler_version)
          recommendation = bundler_gem_version.spermy_recommendation.gsub(/~>\s*(.+)$/, '\1.')
          recommends_default = DEFAULT.index(recommendation) == 0
          default_newer_than_requested = Gem::Version.new(DEFAULT) > bundler_gem_version
          (recommends_default && default_newer_than_requested) ? DEFAULT : bundler_version
        end
      end

      def scan_bundler(dep_section)
        dep_section.scan(/^\s*bundler\s*\((>?=|~>)\s*([^,\)]+)/).first
      end
    end
  end
end
