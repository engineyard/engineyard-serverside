require 'spec_helper'

describe "Deploying an application that uses Node.js and NPM" do
  def deploy_test_application
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new({
        "strategy"      => "NodeIntegrationSpec",
        "deploy_to"     => @deploy_dir,
        "group"         => `id -gn`.strip,
        "stack"         => 'nginx_nodejs',
        'app'           => 'nodeapp',
        'framework_env' => 'staging',
        'deploy_user'   => 'testuser'
      })

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  before(:all) do
    deploy_test_application
  end

  it "runs 'npm install'" do
    install_cmd = @deployer.commands.grep(/npm install/).first
    install_cmd.should_not be_nil
  end
end if $NPM_INSTALLED


