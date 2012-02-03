require 'spec_helper'

describe "Deploying an application without Bundler" do
  before(:all) do
    $DISABLE_GEMFILE = true # Don't generate Gemfile/Gemfile.lock
    $DISABLE_LOCKFILE = true
    @deploy_dir = Pathname.new(Dir.tmpdir).join("serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

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
    @deployer = FullTestDeploy.new(config, test_shell)
    @deployer.deploy
  end

  def exist
    be_exist
  end

  it "creates a REVISION file" do
    @deploy_dir.join('current', 'REVISION').should exist
  end

  it "restarts the app servers" do
    @deploy_dir.join('current', 'restart').should exist
  end

  it "runs all the hooks" do
    @deploy_dir.join('current', 'before_bundle.ran' ).should exist
    @deploy_dir.join('current', 'after_bundle.ran'  ).should exist
    @deploy_dir.join('current', 'before_migrate.ran').should exist
    @deploy_dir.join('current', 'after_migrate.ran' ).should exist
    @deploy_dir.join('current', 'before_compile_assets.ran').should exist
    @deploy_dir.join('current', 'after_compile_assets.ran' ).should exist
    @deploy_dir.join('current', 'before_symlink.ran').should exist
    @deploy_dir.join('current', 'after_symlink.ran' ).should exist
    @deploy_dir.join('current', 'before_restart.ran').should exist
    @deploy_dir.join('current', 'after_restart.ran' ).should exist
  end

end
