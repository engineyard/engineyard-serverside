require 'spec_helper'

describe "Deploying an application with services" do
  before(:each) do
    #$DISABLE_GEMFILE = true # Don't generate Gemfile/Gemfile.lock
    #$DISABLE_LOCKFILE = true
    @deploy_dir = Pathname.new(Dir.tmpdir).join("serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])
  end

  def setup_deploy
    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new({
        "strategy"      => "IntegrationSpec",
        "deploy_to"     => @deploy_dir.to_s,
        "group"         => `id -gn`.strip,
        "stack"         => 'nginx_passenger',
        "migrate"       => nil,
        'app'           => 'foo',
        'framework_env' => 'staging'
      })

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    FullTestDeploy.new(config, test_shell)
  end

  def exist
    be_exist
  end

  describe "a deploy without ey_config" do
    before do
      @deployer = setup_deploy
      @deployer.mock_gemfile_contents <<-EOF
source :rubygems
gem 'rake'
gem 'pg'
      EOF
      @deployer.mock_lockfile_contents <<-EOF
GEM
  remote: http://rubygems.org/
  specs:
    pg (0.11.0)
    rake (0.9.2.2)

PLATFORMS
  ruby

DEPENDENCIES
  pg
  rake
      EOF
    end

    describe "with services" do
      before do
        @shared_services_file    = @deploy_dir.join('shared',  'config', 'ey_services_config_deploy.yml')
        @services_yml = {"servicio" => {"foo" => "bar"}}.to_yaml
        @deployer.mock_services_setup!("echo '#{@services_yml}' > #{@shared_services_file}")
        @deployer.deploy
      end

      it "warns about missing ey_config" do
        read_stderr.should include("WARNING: Gemfile.lock does not contain ey_config")
      end

    end
    describe "without services" do
      before do
        @deployer.deploy
      end

      it "works without warnings" do
        read_output.should_not =~ /WARNING/
      end

    end
  end

  describe "deploy with invalid yaml ey_services_config_deploy" do
    before do
      @shared_services_file    = @deploy_dir.join('shared',  'config', 'ey_services_config_deploy.yml')
      @symlinked_services_file = @deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml')
      @invalid_services_yml = "42"

      @deployer = setup_deploy
      @deployer.mock_services_setup!("echo '#{@invalid_services_yml}' > #{@shared_services_file}")
      @deployer.deploy
    end

    it "works without warning" do
      @shared_services_file.should exist
      @shared_services_file.should_not be_symlink
      @shared_services_file.read.should == "#{@invalid_services_yml}\n"

      @symlinked_services_file.should exist
      @symlinked_services_file.should be_symlink
      @shared_services_file.read.should == "#{@invalid_services_yml}\n"

      read_output.should_not =~ /WARNING/
    end
  end

  describe "a succesful deploy" do
    before do
      @shared_services_file    = @deploy_dir.join('shared',  'config', 'ey_services_config_deploy.yml')
      @symlinked_services_file = @deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml')
      @services_yml = {"servicio" => {"foo" => "bar"}}.to_yaml

      @deployer = setup_deploy
      @deployer.mock_services_setup!("echo '#{@services_yml}' > #{@shared_services_file}")
      @deployer.deploy
    end

    it "creates and symlinks ey_services_config_deploy.yml" do
      @shared_services_file.should exist
      @shared_services_file.should_not be_symlink
      @shared_services_file.read.should == "#{@services_yml}\n"

      @symlinked_services_file.should exist
      @symlinked_services_file.should be_symlink
      @shared_services_file.read.should == "#{@services_yml}\n"

      read_output.should_not =~ /WARNING/
    end

    describe "followed by a deploy that can't find the command" do
      before do
        @deployer = setup_deploy
        @deployer.mock_services_command_check!("which nonexistatncommand")
        @deployer.deploy
      end

      it "silently fails" do
        @shared_services_file.should exist
        @shared_services_file.should_not be_symlink
        @shared_services_file.read.should == "#{@services_yml}\n"

        @symlinked_services_file.should exist
        @symlinked_services_file.should be_symlink
        @shared_services_file.read.should == "#{@services_yml}\n"

        read_output.should_not =~ /WARNING/
      end

    end

    describe "followed by a deploy that fails to fetch services" do
      before do
        @deployer = setup_deploy
        @deployer.mock_services_setup!("notarealcommandsoitwillexitnonzero")
      end

      it "logs a warning and symlinks the existing config file when there is existing services file" do
        @deployer.deploy

        @shared_services_file.should exist
        @shared_services_file.should_not be_symlink
        @shared_services_file.read.should == "#{@services_yml}\n"

        @symlinked_services_file.should exist
        @symlinked_services_file.should be_symlink
        @shared_services_file.read.should == "#{@services_yml}\n"

        read_stderr.should include('WARNING: External services configuration not updated')
      end

      it "does not log a warning or symlink a config file when there is no existing services file" do
        FileUtils.rm(@shared_services_file)
        @deployer.deploy

        @shared_services_file.should_not exist
        @symlinked_services_file.should_not exist

        read_output.should_not =~ /WARNING/
      end

    end

    describe "followed by another successfull deploy" do
      before do
        @deployer = setup_deploy
        @services_yml = {"servicio" => {"foo" => "bar2"}}.to_yaml

        @deployer.mock_services_setup!("echo '#{@services_yml}' > #{@shared_services_file}")
        @deployer.deploy
      end

      it "replaces the config with the new one (and symlinks)" do
        @shared_services_file.should exist
        @shared_services_file.should_not be_symlink
        @shared_services_file.read.should == "#{@services_yml}\n"

        @symlinked_services_file.should exist
        @symlinked_services_file.should be_symlink
        @shared_services_file.read.should == "#{@services_yml}\n"

        read_output.should_not =~ /WARNING/
      end

    end

  end

end
