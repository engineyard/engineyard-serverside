require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  def deploy_test_application(assets_enabled = true, &block)
    $DISABLE_GEMFILE = false
    $DISABLE_LOCKFILE = false
    @deploy_dir = Dir.mktmpdir("serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    @config = EY::Serverside::Deploy::Configuration.new({
      "strategy"      => "IntegrationSpec",
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

    # Set up the application directory to have the requested asset options.
    prepare_rails31_app(assets_enabled)

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(@config)
    @deployer.deploy(&block)
  end

  def prepare_rails31_app(assets_enabled)
    FileUtils.mkdir_p(File.join(@config.release_path, 'config'))
      app_rb = File.join(@config.release_path, 'config', 'application.rb')
      app_rb_contents = <<-EOF
module Rails31
  class Application < Rails::Application
    config.assets.enabled = #{assets_enabled ? 'true' : 'false'}
  end
end
EOF
      File.open(app_rb, 'w') {|f| f.write(app_rb_contents)}
      rakefile = File.join(@config.release_path, 'Rakefile')
      rakefile_contents = <<-EOF
desc 'Precompile yar assetz'
task 'assets:precompile' do
  sh 'touch precompiled'
end
EOF
    File.open(rakefile, 'w') {|f| f.write(rakefile_contents)}
    FileUtils.mkdir_p(File.join(@config.release_path, 'app', 'assets'))
  end

  context "with default production settings" do
    before(:all) do
      deploy_test_application
    end

    it "precompiles assets" do
      File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_true
    end
  end

  context "with asset support disabled in its config" do
    before(:all) do
      deploy_test_application(with_assets = false)
    end

    it "does not precompile assets" do
      File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_false
    end
  end

  context "and failing with errors" do
    before(:all) do
      begin
        deploy_test_application(with_assets = false) do
          deploy_dir = File.join(@config.shared_path, 'cached-copy', 'deploy')
          FileUtils.mkdir_p(deploy_dir)
          hook = File.join(deploy_dir, 'before_migrate.rb')
          hook_contents = %Q[raise 'aaaaaaahhhhh']
          File.open(hook, 'w') {|f| f.puts(hook_contents) }
          File.chmod(0755, hook)
        end
      rescue EY::Serverside::RemoteFailure
      end
    end

    it "retains the failed release" do
      release_name = File.basename(@config.release_path)
      File.directory?(File.join(@deploy_dir, 'releases_failed', release_name)).should be_true
    end
  end

  context "with existing precompilation in a deploy hook" do
    before(:all) do
      deploy_test_application do
        deploy_dir = File.join(@config.shared_path, 'cached-copy', 'deploy')
        FileUtils.mkdir_p(deploy_dir)
        hook = File.join(deploy_dir, 'before_migrate.rb')
        hook_contents = %Q[run 'touch custom_compiled && mkdir public/assets']
        File.open(hook, 'w') {|f| f.puts(hook_contents) }
        File.chmod(0755, hook)
      end
    end

    it "does not replace the public/assets directory" do
      File.exist?(File.join(@deploy_dir, 'current', 'custom_compiled')).should be_true
      File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_false
      File.directory?(File.join(@deploy_dir, 'current', 'public', 'assets')).should be_true
      File.symlink?(File.join(@deploy_dir, 'current', 'public', 'assets')).should be_false
    end
  end
end
