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

    EY::Serverside::LoggedOutput.verbose = true
    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    FullTestDeploy.new(config)
  end

  def exist
    be_exist
  end

  describe "a succesful deploy" do
    before do
      @shared_services_file    = @deploy_dir.join('shared',  'config', 'ey_services_config_deploy.yml')
      @symlinked_services_file = @deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml')

      @deployer = setup_deploy
      @deployer.set_services_fetcher_value({"a_service" => {"b_key" => "c_value"}})
      @deployer.deploy
    end

    it "creates and symlinks ey_services_config_deploy.yml" do
      @shared_services_file.should exist
      @shared_services_file.should_not be_symlink
      @shared_services_file.read.should == YAML.dump({"a_service" => {"b_key" => "c_value"}})

      @symlinked_services_file.should exist
      @symlinked_services_file.should be_symlink
      @shared_services_file.read.should == YAML.dump({"a_service" => {"b_key" => "c_value"}})

      @deployer.infos.should_not be_any { |info| info =~ /WARNING/ }
    end

    describe "followed by a deploy that fails to fetch services" do
      before do
        @deployer = setup_deploy
        @deployer.services_fetcher_breaks!
        @deployer.deploy
      end

      it "logs a warning and symlinks the existing config file" do
        @shared_services_file.should exist
        @shared_services_file.should_not be_symlink
        @shared_services_file.read.should == YAML.dump({"a_service" => {"b_key" => "c_value"}})

        @symlinked_services_file.should exist
        @symlinked_services_file.should be_symlink
        @shared_services_file.read.should == YAML.dump({"a_service" => {"b_key" => "c_value"}})

        @deployer.infos.should be_any { |info| info =~ /WARNING: External services configuration not updated/ }
      end

    end

    describe "followed by another successfull deploy" do
      before do
        @deployer = setup_deploy
        @deployer.set_services_fetcher_value({"other_service" => nil})
        @deployer.deploy
      end

      it "replaces the config with the new one (and symlinks)" do
        @shared_services_file.should exist
        @shared_services_file.should_not be_symlink
        @shared_services_file.read.should == YAML.dump({"other_service" => nil })

        @symlinked_services_file.should exist
        @symlinked_services_file.should be_symlink
        @shared_services_file.read.should == YAML.dump({"other_service" => nil})

        @deployer.infos.should_not be_any { |info| info =~ /WARNING/ }
      end

    end

  end


#  it "creates and symlinks ey_services_config_deploy.yml" do
#    shared_services_file    = @deploy_dir.join('shared',  'config', 'ey_services_config_deploy.yml')
#    symlinked_services_file = @deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml')
#
#    @deployer.deploy
#
#    shared_services_file.should exist
#    shared_services_file.should_not be_symlink
#
#    symlinked_services_file.should exist
#    symlinked_services_file.should be_symlink
#  end
#
#  it "prints a warning if it couldn't access the services api" do
#    @deployer.deploy
#
#    shared_services_file    = @deploy_dir.join('shared',  'config', 'ey_services_config_deploy.yml')
#    symlinked_services_file = @deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml')
#
#    @deployer.services_fetcher_breaks!
#    @deployer.deploy
#
#
#    shared_services_file.should exist
#    shared_services_file.should_not be_symlink
#
#    symlinked_services_file.should exist
#    symlinked_services_file.should be_symlink
#  end
end
