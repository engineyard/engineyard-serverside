class FullTestDeploy < EY::Deploy
  attr_reader :infos, :debugs, :commands

  def initialize(*)
    super
    @infos = []
    @debugs = []
    @commands = []
  end

  # stfu
  def info(msg)
    @infos << msg
  end

  # no really, stfu
  def debug(msg)
    @debugs << msg
  end

  # passwordless sudo is neither guaranteed nor desired
  def sudo(cmd)
    run(cmd)
  end

  def run(cmd)
    # $stderr.puts(cmd)
    @commands << cmd
    super unless skip_command?(cmd)
  end

  def skip_command?(cmd)
    case cmd
      when /^monit/
        true
      else
        false
    end
  end

  # we're probably running this spec under bundler, but a real
  # deploy does not
  def bundle
    my_env = ENV.to_hash

    ENV.delete("BUNDLE_GEMFILE")
    ENV.delete("BUNDLE_BIN_PATH")

    result = super

    ENV.replace(my_env)
    result
  end

  def get_bundler_installer(lockfile)
    installer = super
    installer.options << ' --quiet'   # stfu already!
    installer
  end

end

module EY::Strategies::IntegrationSpec
  module Helpers

    def update_repository_cache
      cached_copy = File.join(c.shared_path, 'cached-copy')

      FileUtils.mkdir_p(cached_copy)
      Dir.chdir(cached_copy) do
        `echo "this is my file; there are many like it, but this one is mine" > file`
        File.open('Gemfile', 'w') do |f|
          f.write <<-EOF
source :gemcutter

gem "bundler", "~> 1.0.0.rc.6"
gem "rake"
EOF
        end

        File.open("Gemfile.lock", "w") do |f|
          f.write <<-EOF
GEM
  remote: http://rubygems.org/
  specs:
    rake (0.8.7)

PLATFORMS
  ruby

DEPENDENCIES
  bundler (~> 1.0.0.rc.6)
  rake
EOF
        end
      end
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
      "FONDLED THE CODE"
    end

  end
end
