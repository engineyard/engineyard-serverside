$LOAD_PATH.push File.expand_path("../lib", File.dirname(__FILE__))

unless defined?(Bundler)
  require 'rubygems'
end

if ENV['COVERAGE']
  # Ruby 1.9.x only.
  require 'simplecov'
  SimpleCov.start do
    add_filter "lib/vendor/"
  end
end

require 'pp'
require 'engineyard-serverside'
require 'engineyard-serverside-adapter'
require File.expand_path('../support/integration', __FILE__)

FIXTURES_DIR = Pathname.new(__FILE__).dirname.join("fixtures")
TMPDIR = Pathname.new(__FILE__).dirname.parent.join('tmp')
GROUP = `id -gn`.strip

module EY
  module Serverside
    def self.dna_json=(j)
      @dna_json = j
      @node = nil
    end

    class Strategies::Git
      def short_log_message(_) "" end
    end
  end
end

Spec::Runner.configure do |config|
  $NPM_INSTALLED = system('which npm 2>&1')
  unless $NPM_INSTALLED
    $stderr.puts "npm not found; skipping Node.js specs."
  end

  $COMPOSER_INSTALLED = system('command -v composer > /dev/null')
  if $COMPOSER_INSTALLED
    $stderr.puts "composer found; skipping tests that expect it to be missing."
  else
    $stderr.puts "composer not found; skipping tests that expect it to be available."
  end

  config.before(:all) do
    make_tmpdir
    EY::Serverside.dna_json = MultiJson.dump({})
  end

  config.after(:all) do
    delete_tmpdir
  end

  class VerboseStringIO < StringIO
    def <<(str)
      if ENV['VERBOSE'] || ENV['DEBUG']
        STDERR << str
      end
      super
    end
  end

  def tmpdir
    TMPDIR
  end

  def make_tmpdir
    tmpdir.mkpath
  end

  def delete_tmpdir
    tmpdir.exist? && tmpdir.rmtree
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

  def capture
    begin
      $stdout = @stdout = VerboseStringIO.new
      $stderr = @stderr = VerboseStringIO.new
      yield
    ensure
      $stdout, $stderr = STDOUT, STDERR
    end
  end

  def test_shell(verbose=true)
    @test_shell ||= begin
                      @log_path = tmpdir.join("serverside-deploy-#{Time.now.to_i}-#{$$}.log")
                      EY::Serverside::Shell.new(:verbose => verbose, :log_path => @log_path, :stdout => stdout, :stderr => stderr)
                    end
  end

  def exist
    be_exist
  end

  def deploy_dir
    @deploy_dir ||= tmpdir.join("serverside-deploy-#{Time.now.to_i}-#{$$}")
  end

  # set up EY::Serverside::Server like we're on a solo
  def test_servers
    @test_servers ||= EY::Serverside::Servers.from_hashes([{:hostname => 'localhost', :roles => %w[solo], :user => ENV['USER']}])
  end

  # When a repo fixture name is specified, the files found in the specified
  # spec/fixtures/repos dir are copied into the test github repository.
  def deploy_test_application(repo_fixture_name = 'default', extra_config = {}, &block)
    options = {
      "strategy"         => "IntegrationSpec",
      "deploy_to"        => deploy_dir.to_s,
      "group"            => GROUP,
      "stack"            => 'nginx_passenger',
      "migrate"          => "ruby -e 'puts ENV[\"PATH\"]' > #{deploy_dir}/path-when-migrating",
      "app"              => 'rails31',
      "environment_name" => 'env',
      "account_name"     => 'acc',
      "framework_env"    => 'staging',
      "branch"           => 'somebranch',
      "verbose"          => true,
      "repo"             => FIXTURES_DIR.join('repos', repo_fixture_name),
    }.merge(extra_config)

    # pretend there is a shared bundled_gems directory
    deploy_dir.join('shared', 'bundled_gems').mkpath
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
      deploy_dir.join('shared', 'bundled_gems', name).open("w") { |f| f.write("old\n") }
    end

    # Create the command to send to CLI.start, even though most of the options are ignored
    @adapter = EY::Serverside::Adapter.new do |args|
      args.app              = options['app']
      args.environment_name = options['environment_name']
      args.account_name     = options['account_name']
      args.migrate          = options['migrate']
      args.ref              = options['branch']
      args.repo             = options['repo']
      args.config           = {
        "services_check_command" => "which echo",
        "services_setup_command" => "echo 'services setup command'",
        "strategy" => options["strategy"],
        "deploy_to" => options["deploy_to"],
        "group" => options["group"]
      }.merge(options['config'] || {})
      args.framework_env    = options['framework_env']
      args.stack            = options['stack']
      args.verbose          = options['verbose']
      args.instances        = test_servers.map {|s| {:hostname => s.hostname, :roles => s.roles.to_a, :name => s.name} }
    end

    @argv = @adapter.deploy.commands.last.to_argv[2..-1]

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    FullTestDeploy.on_create_callback = block
    capture do
      EY::Serverside::CLI.start(@argv)
    end
  ensure
    @deployer = EY::Serverside::Deploy.deployer
    @config = EY::Serverside::Deploy.config
  end

  def redeploy_test_application(extra_config = {}, &block)
    raise "Please deploy_test_application first" unless @argv

    @action = @adapter.deploy do |args|
      extra_config.each do |key,val|
        case key
        when 'branch' then args.ref    = val
        when 'config' then args.config = args.config.merge(val || {})
        else               args.send("#{key}=", val)
        end
      end
    end

    @argv = @action.commands.last.to_argv[2..-1]

    FullTestDeploy.on_create_callback = block
    capture do
      EY::Serverside::CLI.start(@argv)
    end
  ensure
    @deployer = EY::Serverside::Deploy.deployer
    @config = EY::Serverside::Deploy.config
  end
end
