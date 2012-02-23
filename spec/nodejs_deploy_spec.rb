require 'spec_helper'

describe "Deploying an application that uses Node.js and NPM" do
  def deploy_test_application
    @deploy_dir = Pathname.new(Dir.tmpdir).join("serverside-deploy-#{Time.now.to_i}-#{$$}")

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
        'framework_env' => 'staging'
      })

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config, test_shell)
    @deployer.deploy do
      FileUtils.mkdir_p(config.repository_cache) # block runs before deploy
      @deployer.generate_package_json_in(config.repository_cache)
    end
  end

  before(:all) do
    deploy_test_application
  end

  it "runs 'npm install'" do
    install_cmd = @deployer.commands.grep(/npm install/).first
    install_cmd.should_not be_nil
  end
end if $NPM_INSTALLED


