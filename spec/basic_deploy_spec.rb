require 'spec_helper'

describe "Deploying an application without Bundler" do
  before(:all) do
    $DISABLE_GEMFILE = true # Don't generate Gemfile/Gemfile.lock
    $DISABLE_LOCKFILE = true
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new({
        "strategy"      => "IntegrationSpec",
        "deploy_to"     => @deploy_dir,
        "group"         => `id -gn`.strip,
        "stack"         => 'nginx_passenger',
        "migrate"       => nil,
        'app'           => 'foo',
        'framework_env' => 'staging'
      })

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  it "creates a REVISION file" do
    File.exist?(File.join(@deploy_dir, 'current', 'REVISION')).should be_true
  end

  it "restarts the app servers" do
    File.exist?(File.join(@deploy_dir, 'current', 'restart')).should be_true
  end

  it "runs all the hooks" do
    File.exist?(File.join(@deploy_dir, 'current', 'before_bundle.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_bundle.ran'  )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_migrate.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_migrate.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_compile_assets.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_compile_assets.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_symlink.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_symlink.ran' )).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'before_restart.ran')).should be_true
    File.exist?(File.join(@deploy_dir, 'current', 'after_restart.ran' )).should be_true
  end
end
