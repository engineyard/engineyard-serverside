require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/lib/full_test_deploy'
require File.dirname(__FILE__) + '/support/spec_deploy_strategy'

describe "deploying an application" do

  before(:all) do
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")
    FileUtils.mkdir_p(@deploy_dir)

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    setup_dna_json(:app_name => 'myfirstapp')

    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new({
        "strategy"      => "DeployIntegrationSpec",
        "deploy_to"     => @deploy_dir,
        "group"         => `id -gn`.strip,
        "stack"         => 'nginx_passenger',
        "migrate"       => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating",
        'app'           => 'myfirstapp',
        'framework_env' => 'staging'
      })

    # pretend there is a shared bundled_gems directory
    FileUtils.mkdir_p(File.join(@deploy_dir, 'shared', 'bundled_gems'))
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
      File.open(File.join(@deploy_dir, 'shared', 'bundled_gems', name), "w") { |f| f.write("old\n") }
    end

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))

    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  it "creates a REVISION file" do
    File.exist?(File.join(@deploy_dir, 'current', 'REVISION')).should be_true
  end

  it "creates a ruby version file" do
    File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'RUBY_VERSION')).should be_true
  end

  it "creates a system version file" do
    File.exist?(File.join(@deploy_dir, 'shared', 'bundled_gems', 'SYSTEM_VERSION')).should be_true
  end

  if RUBY_VERSION != '1.8.6'
    it "runs the right bundler command" do
      install_bundler_command_ran = @deployer.commands.detect{ |command| command.index("install_bundler") }
      install_bundler_command_ran.should_not be_nil
      install_bundler_command_ran.should == "#{@binpath} _#{EY::Serverside::VERSION}_ install_bundler 1.0.10"
    end

    it "runs 'bundle install' with --deployment" do
      bundle_install_cmd = @deployer.commands.grep(/bundle _\S+_ install/).first
      bundle_install_cmd.should_not be_nil
      bundle_install_cmd.should include('--deployment')
    end

    it "creates binstubs somewhere out of the way" do
      File.exist?(File.join(@deploy_dir, 'current', 'ey_bundler_binstubs', 'rake')).should be_true
    end

    it "has the binstubs in the path when migrating" do
      File.read(File.join(@deploy_dir, 'path-when-migrating')).should include('ey_bundler_binstubs')
    end

    it "removes bundled_gems directory if the ruby version changed" do
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      clear_bundle_cmd.should_not be_nil
    end

    it "removes bundled_gems directory if the system version changed" do
      clear_bundle_cmd = @deployer.commands.grep(/rm -Rf \S+\/bundled_gems/).first
      clear_bundle_cmd.should_not be_nil
    end

    it "creates binstubs somewhere out of the way" do
      File.exist?(File.join(@deploy_dir, 'current', 'ey_bundler_binstubs', 'rake')).should be_true
    end
  end

  it "runs 'npm install'" do
    pending
    bundle_install_cmd = @deployer.commands.grep(/npm install/).first
    bundle_install_cmd.should_not be_nil
  end

  it "generates a database.yml file" do
    pending
    File.exist?(File.join(@deploy_dir, 'current', 'config', 'database.yml')).should be_true
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

  it "restarts the app servers" do
    File.exist?(File.join(@deploy_dir, 'current', 'restart')).should be_true
  end
end
