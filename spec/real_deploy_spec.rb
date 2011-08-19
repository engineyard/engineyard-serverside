require File.dirname(__FILE__) + '/spec_helper'

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

describe "deploying an application" do
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

  before(:all) do
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")
    @custom_without_group = "bob"

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new({
        "strategy"      => "IntegrationSpec",
        "deploy_to"     => @deploy_dir,
        "group"         => `id -gn`.strip,
        "stack"         => 'nginx_passenger',
        "migrate"       => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating",
        'app'           => 'foo',
        'framework_env' => 'staging',
        "bundler"       => {"group_exclude" => ["development", "test", @custom_without_group]}
      })

    # pretend there is a shared bundled_gems directory
    FileUtils.mkdir_p(File.join(@deploy_dir, 'shared', 'bundled_gems'))
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name| 
      File.open(File.join(@deploy_dir, 'shared', 'bundled_gems', name), "w") { |f| f.write("old\n") }
    end

    @binpath = $0 = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  it "runs the right bundler command" do
    install_bundler_command_ran = @deployer.commands.detect{ |command| command.index("install_bundler") }
    install_bundler_command_ran.should_not be_nil
    install_bundler_command_ran.should == "#{@binpath} _#{EY::Serverside::VERSION}_ install_bundler 1.0.10"
  end

  it "creates a REVISION file" do
    File.exist?(File.join(@deploy_dir, 'current', 'REVISION')).should be_true
  end

  it "restarts the app servers" do
    File.exist?(File.join(@deploy_dir, 'current', 'restart')).should be_true
  end

  it "runs 'bundle install' with --deployment" do
    bundle_install_cmd = @deployer.commands.grep(/bundle _\S+_ install/).first
    bundle_install_cmd.should_not be_nil
    bundle_install_cmd.should include('--deployment')
  end

  it "runs 'bundle install' with custom --without options" do
    bundle_install_cmd = @deployer.commands.grep(/bundle _\S+_ install/).first
    bundle_install_cmd.should_not be_nil
    bundle_install_cmd.should include("--without development test #{@custom_without_group}")
  end

  it "creates a ruby version file" do
    File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'RUBY_VERSION')).should be_true
  end

  it "creates a system version file" do
    File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'SYSTEM_VERSION')).should be_true
  end

  it "removes bundled_gems directory if the ruby version changed" do
    clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
    clear_bundle_cmd.should_not be_nil
  end

  it "removes bundled_gems directory if the system version changed" do
    clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
    clear_bundle_cmd.should_not be_nil
  end

  it "creates binstubs somewhere out of the way" do
    File.exist?(File.join(@deploy_dir, 'current', 'ey_bundler_binstubs', 'rake')).should be_true
  end

  it "has the binstubs in the path when migrating" do
    File.read(File.join(@deploy_dir, 'path-when-migrating')).should include('ey_bundler_binstubs')
  end

  it "runs all the hooks" do
    File.exist?(File.join(@deploy_dir, 'current', 'before_bundle.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_bundle.ran'  )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_migrate.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_migrate.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_symlink.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_symlink.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_restart.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_restart.ran' )).should be_true
  end
end
