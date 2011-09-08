require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/lib/full_test_deploy'
require File.dirname(__FILE__) + '/support/spec_deploy_strategy'

describe "Deploying a Rails 3.1 application" do
  before(:each) do
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")
    FileUtils.mkdir_p(@deploy_dir)
    prepare_new_deployment
  end

  def prepare_new_deployment
    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    setup_dna_json(:app_name => 'rails31', :framework_env => 'staging')

    # run a deploy
    @deploy_config = EY::Serverside::Deploy::Configuration.new({
      "strategy"      => "DeployIntegrationSpec",
      "deploy_to"     => @deploy_dir,
      "group"         => `id -gn`.strip,
      "stack"         => 'nginx_passenger',
      "migrate"       => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating",
      'app'           => 'rails31',
      'framework_env' => 'staging'
    })

    # pretend there is a shared bundled_gems directory
    FileUtils.mkdir_p(File.join(@deploy_dir, 'shared', 'bundled_gems'))
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
      File.open(File.join(@deploy_dir, 'shared', 'bundled_gems', name), "w") { |f| f.write("old\n") }
    end

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
  end

  def deploy_rails31(assets_enabled = true, asset_filename = 'hello')
    config = @deploy_config
    FileUtils.mkdir_p(File.join(config.release_path, 'config'))
      app_rb = File.join(config.release_path, 'config', 'application.rb')
      app_rb_contents = <<-EOF
module Rails31
  class Application < Rails::Application
    config.assets.enabled = #{assets_enabled ? 'true' : 'false'}
  end
end
EOF
      File.open(app_rb, 'w') {|f| f.write(app_rb_contents)}
      rakefile = File.join(config.release_path, 'Rakefile')
      rakefile_contents = <<-EOF
task 'assets:precompile' do
  sh 'touch precompiled && mkdir -p public/assets && touch public/assets/#{asset_filename} 2>/dev/null'
end
EOF
    File.open(rakefile, 'w') {|f| f.write(rakefile_contents)}

    FileUtils.mkdir_p(File.join(config.release_path, 'app', 'assets'))

    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  it "saves public/assets as public/last_assets if it exists" do
    deploy_rails31(true)
    File.readable?(File.join(@deploy_dir, 'current', 'precompiled')).should be_true
    File.symlink?(File.join(@deploy_dir, 'current', 'public', 'assets')).should be_true
    File.symlink?(File.join(@deploy_dir, 'current', 'public', 'last_assets')).should be_true

    prepare_new_deployment
    deploy_rails31(true, 'not_hello')
    File.exist?(File.join(@deploy_dir, 'current', 'public', 'assets', 'hello')).should be_false
    File.exist?(File.join(@deploy_dir, 'current', 'public', 'last_assets', 'hello')).should be_true
  end

  it "does not precompile assets if they are disabled in the application config" do
    deploy_rails31(false)
    File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_false
    File.directory?(File.join(@deploy_dir, 'current', 'public', 'last_assets')).should_not be_true
  end
end
