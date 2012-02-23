class FullTestDeploy < EY::Serverside::Deploy
  attr_reader :commands

  def initialize(*)
    super
    @commands = []
    @gemfile_contents = nil
    @lockfile_contents = nil
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

    if defined?(Bundler)
      Bundler.with_clean_env do
        result = super
      end
    else
      result = super
    end

    ENV.replace(my_env)
    result
  end

  def deploy
    yield(self) if block_given?
    super
  end

  def services_command_check
    @mock_services_command_check || "which echo"
  end

  def mock_services_command_check!(value)
    @mock_services_command_check = value
  end

  def services_setup_command
    @mock_services_setup_command || "echo 'skipped'"
  end

  def mock_services_setup!(value)
    @mock_services_setup_command = value
  end

  def mock_gemfile_contents(gemfile_contents)
    @gemfile_contents = gemfile_contents
  end

  def mock_lockfile_contents(lockfile_contents)
    @lockfile_contents = lockfile_contents
  end

end

module EY::Serverside::Strategies::IntegrationSpec
  module Helpers


    def update_repository_cache
      cached_copy = c.repository_cache

      deploy_hook_dir = File.join(cached_copy, 'deploy')
      FileUtils.mkdir_p(deploy_hook_dir)
      %w[bundle compile_assets migrate symlink restart].each do |action|
        %w[before after].each do |prefix|
          hook = "#{prefix}_#{action}"
          hook_path = File.join(deploy_hook_dir, "#{hook}.rb")
          next if File.exist?(hook_path)
          File.open(hook_path, 'w') do |f|
            f.write(%Q{run 'touch "#{c.release_path}/#{hook}.ran"'})
          end
        end
      end

      FileUtils.mkdir_p(File.join(c.shared_path, 'config'))
      FileUtils.mkdir_p(cached_copy)
      generate_gemfile_in(cached_copy)
    end

    def release_path
      c.release_path
    end

    def shared_path
      c.shared_path
    end

    def framework_env
      c.framework_env
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
      "FONDLED THE CODE"
    end

    def gemfile_contents=(contents)
      @gemfile_contents = contents
    end

    def gemfile_contents
      @gemfile_contents || <<-EOF
source :rubygems
gem 'rake'
gem 'pg'
gem 'ey_config'
      EOF
    end

    def lockfile_contents=(contents)
      @lockfile_contents = contents
    end

    # Generated using Bundler v1.0.21

    def lockfile_contents
      @lockfile_contents || <<-EOF
GEM
  remote: http://rubygems.org/
  specs:
    pg (0.11.0)
    rake (0.9.2.2)
    ey_config (0.0.1)

PLATFORMS
  ruby

DEPENDENCIES
  pg
  rake
  ey_config
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

module EY::Serverside::Strategies::NodeIntegrationSpec
  module Helpers
    include EY::Serverside::Strategies::IntegrationSpec::Helpers

    def generate_gemfile_in(dir)
      super(dir)
    end

    def generate_package_json_in(dir)
      npm_file = File.join(dir, 'package.json')
      File.open(npm_file, 'w') {|f| f.write(npm_content)}
    end

    def npm_content
      <<-EOF
{
  "name": "node-example",
  "version": "0.0.1",
  "dependencies": {
    "express": "2.2.0"
  }
}
EOF
    end
  end
end
