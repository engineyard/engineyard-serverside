require 'spec_helper'

describe "Deploying an application that uses Bundler" do
  VERSION_PATTERN = Regexp.quote(::EY::Serverside::DependencyManager::Bundler.default_version)

  context "with a Gemfile.lock" do
    before(:all) do
      deploy_test_application('ey_yml')
      @install_bundler_command = @deployer.commands.grep(/gem install bundler/).first
      @bundle_install_command  = @deployer.commands.grep(/bundle _#{VERSION_PATTERN}_ install/).first
    end

    it "runs the right bundler command" do
      expect(@install_bundler_command).not_to be_nil
      expect(@install_bundler_command).to match(/install bundler .* -v "#{VERSION_PATTERN}"/)
    end

    it "runs 'bundle install' with --deployment" do
      expect(@bundle_install_command).not_to be_nil
      expect(@bundle_install_command).to include('--deployment')
    end

    it "removes bundled_gems directory if the ruby or system version changed" do
      should_run_clear_bundle_cmd = @deployer.commands.grep(/diff/).first
      expect(should_run_clear_bundle_cmd).not_to be_nil
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      expect(clear_bundle_cmd).not_to be_nil
    end

    it "has the binstubs in the path when migrating" do
      expect(deploy_dir.join('path-when-migrating').read).to include('ey_bundler_binstubs')
    end

    it "creates a ruby version file" do
      expect(deploy_dir.join('shared', 'bundled_gems', 'RUBY_VERSION')).to exist
    end

    it "creates a system version file" do
      expect(deploy_dir.join('shared', 'bundled_gems', 'SYSTEM_VERSION')).to exist
    end

    it "generates bundler binstubs" do
      pending "doesn't work with mocked bundler" do
        expect(deploy_dir.join('current', 'ey_bundler_binstubs', 'rake')).to exist
      end
    end
  end

  context "with clean option" do
    before(:all) do
      deploy_test_application('ey_yml', 'clean' => true)
    end

    it "removes bundled_gems directory if the ruby or system version changed" do
      should_run_clear_bundle_cmd = @deployer.commands.grep(/diff/).first
      expect(should_run_clear_bundle_cmd).to be_nil
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      expect(clear_bundle_cmd).not_to be_nil
    end

  end

  context "with bundler disabled in ey.yml" do
    before(:all) do
      deploy_test_application('bundler_disabled')
    end

    it "does not run bundler commands" do
      expect(@deployer.commands.grep(/gem install bundler/)).to be_empty
      expect(@deployer.commands.grep(/bundle _.*_ install/)).to be_empty
    end

    it "still runs the hooks" do
      expect(deploy_dir.join('current', 'before_bundle.ran' )).to exist
      expect(deploy_dir.join('current', 'after_bundle.ran' )).to exist
    end
  end

  context "without a Gemfile.lock" do
    before(:all) do
      deploy_test_application('no_gemfile_lock')
      @install_bundler_command = @deployer.commands.grep(/gem install bundler/).first
      @bundle_install_command  = @deployer.commands.grep(/bundle _#{VERSION_PATTERN}_ install/).first
    end

    it "installs the proper Bundler version" do
      expect(@install_bundler_command).not_to be_nil
      expect(@install_bundler_command).to match(/unset RUBYOPT && gem list bundler | grep "bundler " | egrep -q "#{VERSION_PATTERN}[,)]" || gem install bundler -q --no-rdoc --no-ri -v "#{VERSION_PATTERN}"/)
    end

    it "runs 'bundle install' without --deployment" do
      expect(@bundle_install_command).not_to be_nil
      expect(@bundle_install_command).not_to match(/--deployment/)
    end

    it "exports GIT_SSH for the bundle install" do
      expect(@bundle_install_command).to match(/export GIT_SSH/)
    end

    it "puts down RUBY_VERSION and SYSTEM_VERSION" do
      expect(deploy_dir.join('shared', 'bundled_gems', 'RUBY_VERSION')).to exist
      expect(deploy_dir.join('shared', 'bundled_gems', 'SYSTEM_VERSION')).to exist
    end

    it "warns that using a lockfile is idiomatic" do
      out = read_output
      expect(out).to match(/WARNING: Gemfile found but Gemfile.lock is missing!/)
    end
  end

  context "without a Gemfile.lock and ignoring the warning" do
    before(:all) do
      deploy_test_application('no_gemfile_lock', 'config' => {'ignore_gemfile_lock_warning' => true})
      expect(@config.ignore_gemfile_lock_warning).to be_true
      @install_bundler_command = @deployer.commands.grep(/gem install bundler/).first
      @bundle_install_command  = @deployer.commands.grep(/bundle _#{VERSION_PATTERN}_ install/).first
    end

    it "should not warn" do
      out = read_output
      expect(out).not_to match(/WARNING/)
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
      expect(out).to match(%r|bundle install failure|)
      expect(deploy_dir.join('current', 'after_bundle.ran' )).not_to exist
    end
  end
end

