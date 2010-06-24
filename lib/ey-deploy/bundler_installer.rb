module EY
  class BundlerInstaller
    def install(version)
      require "rubygems"
      requirement = Gem::Requirement.new(version)

      # these will be ["name-version", Gem::Specification] 2-tuples
      bundler_geminfos = Gem.source_index.find_all { |(name,_)| name =~ /^bundler-\d/ }

      has_this_bundler = bundler_geminfos.any? do |geminfo|
        requirement.satisfied_by?(geminfo.last.version)
      end

      unless has_this_bundler
        system("gem install bundler -q --no-rdoc --no-ri -v '#{version}'")
      end
    end

  end
end
