require 'yaml'
module EY
  class LockfileParser

    attr_reader :bundler_version, :lockfile_version

    def initialize(lockfile_contents)
      @contents = lockfile_contents
      @lockfile_version, @bundler_version = parse
    end

    private
    def parse
      from_yaml = safe_yaml_load(@contents)
      if from_yaml                        # 0.9
        bundler_version = from_yaml['specs'].map do |spec|
          # spec is a one-element hash: the key is the gem name, and
          # the value is {"version" => the-version}.
          if spec.keys.first == "bundler"
            spec.values.first["version"]
          end
        end.compact.first
        [:bundler09, bundler_version]
      else                                # 1.0 or bust
        dep_section = ""
        in_dependencies_section = false
        @contents.each_line do |line|
          if line =~ /^DEPENDENCIES/
            in_dependencies_section = true
          elsif line =~ /^\S/
            in_dependencies_section = false
          elsif in_dependencies_section
            dep_section << line
          end
        end

        unless dep_section.length > 0
          raise "Couldn't parse #{lockfile}; exiting"
          exit(1)
        end

        result = dep_section.scan(/^\s*bundler\s*\(=\s*([^\)]+)\)/).first
        bundler_version = result ? result.first : nil
        [:bundler10, bundler_version]
      end
    end

    def safe_yaml_load(loadable)
      YAML.load(loadable)
    rescue ArgumentError   # not yaml
      nil
    end

  end
end
