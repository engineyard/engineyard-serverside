require 'spec_helper'

describe "Deploying an application that uses Bundler" do
  let(:version_pattern) { Regexp.quote(::EY::Serverside::DependencyManager::Bundler.default_version) }

  context "with a Gemfile.lock" do
    before(:all) do
      deploy_test_application('ey_yml')
      @install_bundler_command = @deployer.commands.grep(/gem install bundler/).first
      @bundle_install_command  = @deployer.commands.grep(/bundle _#{version_pattern}_ install/).first
    end

    it "runs the right bundler command" do
      @install_bundler_command.should_not be_nil
      @install_bundler_command.should =~ /install bundler .* -v "#{version_pattern}"/
    end

    it "runs 'bundle install' with --deployment" do
      @bundle_install_command.should_not be_nil
      @bundle_install_command.should include('--deployment')
    end

    it "removes bundled_gems directory if the ruby or system version changed" do
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      clear_bundle_cmd.should_not be_nil
    end

    it "has the binstubs in the path when migrating" do
      deploy_dir.join('path-when-migrating').read.should include('ey_bundler_binstubs')
    end

    it "creates a ruby version file" do
      deploy_dir.join('shared', 'bundled_gems', 'RUBY_VERSION').should exist
    end

    it "creates a system version file" do
      deploy_dir.join('shared', 'bundled_gems', 'SYSTEM_VERSION').should exist
    end

    it "generates bundler binstubs" do
      deploy_dir.join('current', 'ey_bundler_binstubs', 'rake').should exist
    end
  end

  context "without a Gemfile.lock" do
    before(:all) do
      deploy_test_application('no_gemfile_lock')
      @install_bundler_command = @deployer.commands.grep(/gem install bundler/).first
      @bundle_install_command  = @deployer.commands.grep(/bundle _#{version_pattern}_ install/).first
    end

    it "installs the proper Bundler version" do
      @install_bundler_command.should_not be_nil
      @install_bundler_command.should =~ /unset RUBYOPT && gem list bundler | grep "bundler " | egrep -q "#{version_pattern}[,)]" || gem install bundler -q --no-rdoc --no-ri -v "#{version_pattern}"/
    end

    it "runs 'bundle install' without --deployment" do
      @bundle_install_command.should_not be_nil
      @bundle_install_command.should_not =~ /--deployment/
    end

    it "exports GIT_SSH for the bundle install" do
      @bundle_install_command.should =~ /export GIT_SSH/
    end

    it "puts down RUBY_VERSION and SYSTEM_VERSION" do
      deploy_dir.join('shared', 'bundled_gems', 'RUBY_VERSION').should exist
      deploy_dir.join('shared', 'bundled_gems', 'SYSTEM_VERSION').should exist
    end
  end

  context "with a failing Gemfile" do
    before(:all) do
      begin
        deploy_test_application('bundle_fails', :verbose => false)
      rescue EY::Serverside::RemoteFailure
      end
    end

    it "prints the failure to the log" do
      out = read_output
      out.should =~ %r|this-gem-does-not-exist-which-makes-bundle-install-fail|
      deploy_dir.join('current', 'after_bundle.ran' ).should_not exist
    end
  end
end

