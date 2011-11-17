require 'spec_helper'

describe "Deploying an application that uses Bundler" do
  before(:each) do
    @bundler_version = ::EY::Serverside::LockfileParser.default_version
    @version_pattern = Regexp.quote(@bundler_version)
  end

  def deploy_test_application
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new({
      "strategy"       => "IntegrationSpec",
      "deploy_to"      => @deploy_dir,
      "group"          => `id -gn`.strip,
      "stack"          => 'nginx_passenger',
      "migrate"        => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating",
      'app'            => 'foo',
      'framework_env'  => 'staging',
      'bundle_without' => 'release test',
      'deploy_user'    => 'testuser'
    })

    # pretend there is a shared bundled_gems directory
    FileUtils.mkdir_p(File.join(@deploy_dir, 'shared', 'bundled_gems'))
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
      File.open(File.join(@deploy_dir, 'shared', 'bundled_gems', name), "w") { |f| f.write("old\n") }
    end

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  context "with a Gemfile.lock" do
    before(:all) do
      $DISABLE_GEMFILE = false
      $DISABLE_LOCKFILE = false
      deploy_test_application
    end

    it "runs the right bundler command" do
      install_bundler_command_ran = @deployer.commands.detect{ |command| command.index("install_bundler") }
      install_bundler_command_ran.should_not be_nil
      install_bundler_command_ran.should include("#{@binpath} install_bundler #{@bundler_version}")
    end

    it "runs 'bundle install' with --deployment" do
      bundle_install_cmd = @deployer.commands.grep(/bundle _#{@version_pattern}_ install/).first
      bundle_install_cmd.should_not be_nil
      bundle_install_cmd.should include('--deployment')
    end

    it "removes bundled_gems directory if the ruby version changed" do
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      clear_bundle_cmd.should_not be_nil
    end

    it "removes bundled_gems directory if the system version changed" do
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      clear_bundle_cmd.should_not be_nil
    end

    it "has the binstubs in the path when migrating" do
      File.read(File.join(@deploy_dir, 'path-when-migrating')).should include('ey_bundler_binstubs')
    end

    it "runs 'bundle install' with custom --without options" do
      bundle_install_cmd = @deployer.commands.grep(/bundle _\S+_ install/).first
      bundle_install_cmd.should_not be_nil
      bundle_install_cmd.should include("--without release test")
    end

    it "creates a ruby version file" do
      File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'RUBY_VERSION')).should be_true
    end

    it "creates a system version file" do
      File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'SYSTEM_VERSION')).should be_true
    end

    it "generates bundler binstubs" do
      File.exist?(File.join(@deploy_dir, 'current', 'ey_bundler_binstubs', 'rake')).should be_true
    end
  end

  context "without a Gemfile.lock" do
    before(:all) do
      $DISABLE_GEMFILE = false
      $DISABLE_LOCKFILE = true
      deploy_test_application
    end

    it "installs the proper Bundler version" do
      @bundler_version.should == "1.0.21" # Something should break when the default changes.
      install_bundler_command_ran = @deployer.commands.detect{ |command| command.index("install_bundler") }
      install_bundler_command_ran.should_not be_nil
      install_bundler_command_ran.should include("#{@binpath} install_bundler #{@bundler_version}")
    end

    it "runs 'bundle install' without --deployment" do
      bundle_install_cmd = @deployer.commands.grep(/bundle _#{@version_pattern}_ install/).first
      bundle_install_cmd.should_not be_nil
      bundle_install_cmd.should_not include('--deployment')
    end

    it "creates a ruby version file" do
      File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'RUBY_VERSION')).should be_true
    end

    it "creates a system version file" do
      File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'SYSTEM_VERSION')).should be_true
    end

    it "Sets GIT_SSH environment variable" do
      install_cmd = @deployer.commands.grep(/GIT_SSH/).first
      install_cmd.should match(/export GIT_SSH.*install_bundler/)
    end
  end
end

