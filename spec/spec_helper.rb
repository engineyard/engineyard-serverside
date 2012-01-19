$LOAD_PATH.push File.expand_path("../lib", File.dirname(__FILE__))

if defined?(Bundler)
  Bundler.require :default, :test
else
  require 'rubygems'
end

require 'pp'
require 'engineyard-serverside'
require File.expand_path('../support/integration', __FILE__)

module EY
  module Serverside
    def self.dna_json=(j)
      @dna_json = j
      @node = nil
    end

    module LoggedOutput
      def info(_) end

      def logged_system(cmd)
        output = `#{cmd} 2>&1`
        successful = ($? == 0)
        if ENV['VERBOSE']
          if successful
            $stdout.puts "#{cmd}\n#{output.strip}".chomp
          else
            $stderr.puts "\nCommand `#{cmd}` exited with status #{$?.exitstatus}: '#{output.strip}'"
          end
        end
        successful
      end
    end

    class Strategies::Git
      def short_log_message(_) "" end
    end
  end
end

FIXTURES_DIR = File.expand_path("../fixtures", __FILE__)
GITREPO_DIR = "#{FIXTURES_DIR}/gitrepo"

FileUtils.rm_rf GITREPO_DIR if File.exists? GITREPO_DIR
Kernel.system "tar xzf #{GITREPO_DIR}.tar.gz -C #{FIXTURES_DIR}"

Spec::Runner.configure do |config|
  `which npm 2>&1`
  $NPM_INSTALLED = ($? == 0)
  unless $NPM_INSTALLED
    $stderr.puts "npm not found; skipping Node.js specs."
  end

  config.before(:all) do
    $DISABLE_GEMFILE = false
    $DISABLE_LOCKFILE = false
    EY::Serverside.dna_json = {}.to_json
  end

    def deploy_test_application(assets_enabled = true, &block)
    $DISABLE_GEMFILE = false
    $DISABLE_LOCKFILE = false
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

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
end
