module FullDeployHelpers
  def setup_deploy_environment
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Server like we're on a solo
    EY::Server.reset
    EY::Server.add(:hostname => 'localhost', :roles => %w[solo])
    
    $0 = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'engineyard-serverside'))
  end

  def run_test_deploy
    setup_deploy_environment

    deployer = FullTestDeploy.new(config_for_deploy)
    deployer.deploy
    deployer
  end

  def config_for_deploy
    EY::Deploy::Configuration.new default_config.merge( @deploy_config || {} )
  end

  def default_config
    { "strategy" => "IntegrationSpec",
      "deploy_to" => @deploy_dir,
      "group" => `id -gn`.strip,
      "migrate" => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating" }
  end
end
