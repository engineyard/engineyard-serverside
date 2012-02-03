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

    class Shell
      def spawn_process(cmd, cmd_stdout, cmd_stderr)
        cmd_stdout << `#{cmd} 2>&1`
        $? == 0
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
  $NPM_INSTALLED = system('which npm 2>&1')
  unless $NPM_INSTALLED
    $stderr.puts "npm not found; skipping Node.js specs."
  end

  config.before(:all) do
    $DISABLE_GEMFILE = false
    $DISABLE_LOCKFILE = false
    EY::Serverside.dna_json = {}.to_json
  end

  class VerboseStringIO < StringIO
    def <<(str)
      if ENV['VERBOSE'] || ENV['DEBUG']
        $stderr << str
      end
      super
    end
  end

  def stdout
    @stdout ||= VerboseStringIO.new
  end

  def stderr
    @stderr ||= VerboseStringIO.new
  end

  def read_stdout
    stdout.rewind
    stdout.read
  end

  def read_stderr
    stderr.rewind
    stderr.read
  end

  def read_output
    read_stdout + "\n" + read_stderr
  end

  def test_shell
    log_path =  Pathname.new(Dir.tmpdir).join("serverside-deploy-#{Time.now.to_i}-#{$$}.log")
    EY::Serverside::Shell.new(:verbose => true, :log_path => log_path, :stdout => stdout, :stderr => stderr)
  end

  def deploy_test_application(assets_enabled = true, &block)
    $DISABLE_GEMFILE = false
    $DISABLE_LOCKFILE = false
    @deploy_dir = Pathname.new(Dir.tmpdir).join("serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    @config = EY::Serverside::Deploy::Configuration.new({
      "strategy"      => "IntegrationSpec",
      "deploy_to"     => @deploy_dir.to_s,
      "group"         => `id -gn`.strip,
      "stack"         => 'nginx_passenger',
      "migrate"       => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating",
      'app'           => 'rails31',
      'framework_env' => 'staging'
    })

    # pretend there is a shared bundled_gems directory
    @deploy_dir.join('shared', 'bundled_gems').mkpath
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
      @deploy_dir.join('shared', 'bundled_gems', name).open("w") { |f| f.write("old\n") }
    end

    # Set up the application directory to have the requested asset options.
    prepare_rails31_app(assets_enabled)

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(@config, test_shell)
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
