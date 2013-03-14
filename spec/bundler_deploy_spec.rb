require 'spec_helper'

describe "Deploying an application that uses Bundler" do
  before(:each) do
    @bundler_version = ::EY::Serverside::LockfileParser.default_version
    @version_pattern = Regexp.quote(@bundler_version)
  end

  context "with a Gemfile.lock" do
    before(:all) do
      deploy_test_application('ey_yml')
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
      File.read(File.join(deploy_dir, 'path-when-migrating')).should include('ey_bundler_binstubs')
    end

    it "creates a ruby version file" do
      File.exist?(File.join(deploy_dir, 'shared', 'bundled_gems', 'RUBY_VERSION')).should be_true
    end

    it "creates a system version file" do
      File.exist?(File.join(deploy_dir, 'shared', 'bundled_gems', 'SYSTEM_VERSION')).should be_true
    end

    it "generates bundler binstubs" do
      File.exist?(File.join(deploy_dir, 'current', 'ey_bundler_binstubs', 'rake')).should be_true
    end
  end

  context "without a Gemfile.lock" do
    before(:all) do
      deploy_test_application('no_gemfile_lock')
    end

    it "installs the proper Bundler version" do
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
      File.exist?(File.join(deploy_dir, 'shared', 'bundled_gems', 'RUBY_VERSION')).should be_true
    end

    it "creates a system version file" do
      File.exist?(File.join(deploy_dir, 'shared', 'bundled_gems', 'SYSTEM_VERSION')).should be_true
    end

    it "sets GIT_SSH environment variable" do
      install_cmd = @deployer.commands.grep(/GIT_SSH/).first
      install_cmd.should match(/export GIT_SSH.*install_bundler/)
    end
  end

  context "with a failing Gemfile" do
    before(:all) do
      begin
        deploy_test_application('bundle_fails', :verbose => false)
      rescue SystemExit
      end
    end

    it "prints the failure to the log" do
      out = read_output
      out.should =~ %r|this-gem-does-not-exist-which-makes-bundle-install-fail|
    end
  end
end

