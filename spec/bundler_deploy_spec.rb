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
      should_run_clear_bundle_cmd = @deployer.commands.grep(/diff/).first
      should_run_clear_bundle_cmd.should_not be_nil
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
      pending "doesn't work with mocked bundler" do
        deploy_dir.join('current', 'ey_bundler_binstubs', 'rake').should exist
      end
    end
  end

  context "with clean option" do
    before(:all) do
      deploy_test_application('ey_yml', 'clean' => true)
    end

    it "removes bundled_gems directory if the ruby or system version changed" do
      should_run_clear_bundle_cmd = @deployer.commands.grep(/diff/).first
      should_run_clear_bundle_cmd.should be_nil
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      clear_bundle_cmd.should_not be_nil
    end

  end

  context "with bundler disabled in ey.yml" do
    before(:all) do
      deploy_test_application('bundler_disabled')
    end

    it "does not run bundler commands" do
      @deployer.commands.grep(/gem install bundler/).should be_empty
      @deployer.commands.grep(/bundle _.*_ install/).should be_empty
    end

    it "still runs the hooks" do
      deploy_dir.join('current', 'before_bundle.ran' ).should exist
      deploy_dir.join('current', 'after_bundle.ran' ).should exist
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

    it "warns that using a lockfile is idiomatic" do
      out = read_output
      out.should =~ %r(WARNING: Gemfile found but Gemfile.lock is missing!)
    end
  end

  context "without a Gemfile.lock and ignoring the warning" do
    before(:all) do
      deploy_test_application('no_gemfile_lock', 'config' => {'ignore_gemfile_lock_warning' => true})
      @config.ignore_gemfile_lock_warning.should be_true
      @install_bundler_command = @deployer.commands.grep(/gem install bundler/).first
      @bundle_install_command  = @deployer.commands.grep(/bundle _#{version_pattern}_ install/).first
    end

    it "should not warn" do
      out = read_output
      out.should_not =~ %r(WARNING)
    end
  end

  context "with a failing Gemfile" do
    before(:all) do
      begin
        deploy_test_application('bundle_fails', 'bundle_install_fails' => true, 'verbose' => false)
      rescue EY::Serverside::RemoteFailure
      end
    end

    it "prints the failure to the log" do
      out = read_output
      out.should =~ %r|bundle install failure|
      deploy_dir.join('current', 'after_bundle.ran' ).should_not exist
    end
  end
end

