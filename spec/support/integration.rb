class FullTestDeploy < EY::Serverside::Deploy
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
    @commands << cmd
    super
  end

  def version_specifier
    # Normally, the deploy task invokes the hook task by executing
    # the rubygems-generated wrapper (it's what's in $PATH). It
    # specifies the version to make sure that the pieces don't get
    # out of sync. However, in test mode, there's no
    # rubygems-generated wrapper, and so the hook task doesn't get
    # run because thor thinks we're trying to invoke the _$VERSION_
    # task instead, which doesn't exist.
    #
    # By stripping that out, we can get the hooks to actually run
    # inside this test.
    nil
  end

  def restart
    FileUtils.touch("#{c.release_path}/restart")
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

module EY::Serverside::Strategies::IntegrationSpec
  module Helpers

    def update_repository_cache
      cached_copy = File.join(c.shared_path, 'cached-copy')

      deploy_hook_dir = File.join(cached_copy, 'deploy')
      FileUtils.mkdir_p(deploy_hook_dir)
      %w[bundle migrate symlink restart].each do |action|
        %w[before after].each do |prefix|
          hook = "#{prefix}_#{action}"
          File.open(File.join(deploy_hook_dir, "#{hook}.rb"), 'w') do |f|
            f.write(%Q{run 'touch "#{c.release_path}/#{hook}.ran"'})
          end
        end
      end

      FileUtils.mkdir_p(File.join(c.shared_path, 'config'))
      FileUtils.mkdir_p(cached_copy)
      generate_gemfile_in(cached_copy)
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
      "FONDLED THE CODE"
    end

    def gemfile_contents
      <<-EOF
source :gemcutter

gem "bundler", "~> 1.0.0.rc.6"
gem "rake"
EOF
    end

    def lockfile_contents
      <<-EOF
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

    def generate_gemfile_in(dir)
      `echo "this is my file; there are many like it, but this one is mine" > #{dir}/file`
      gemfile_path = File.join(dir, 'Gemfile')
      lockfile_path = File.join(dir, 'Gemfile.lock')

      unless $DISABLE_GEMFILE
        File.open(gemfile_path, 'w') {|f| f.write(gemfile_contents) }
      end
      unless $DISABLE_LOCKFILE
        File.open(lockfile_path, 'w') {|f| f.write(lockfile_contents) }
      end
    end
  end
end

