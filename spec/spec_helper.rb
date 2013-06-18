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
INTERNAL_KEY = Pathname.new("~/.ssh/id_rsa").expand_path

module EY
  module Serverside
    def self.dna_json=(j)
      @dna_json = j
      @node = nil
    end

    class Strategies::Git
      def short_log_message(_) "" end
    end


    class Paths
      # This needs to be patched for the tests to succeed, but
      # the chances of 2 real deploys colliding in the same second
      # is very very low.
      def active_release
        @active_release ||= if Time.now.utc.strftime("%L") =~ /L/ # old ruby
                              path(:releases, Time.now.utc.strftime("%Y%m%d%H%M%S#{Time.now.tv_usec}"))
                            else
                              path(:releases, Time.now.utc.strftime("%Y%m%d%H%M%S%L"))
                            end
      end
    end

  end
end

RSpec.configure do |config|
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
                      @log_path = tmpdir.join("serverside-deploy-#{Time.now.to_f}-#{$$}.log")
                      EY::Serverside::Shell.new(:verbose => verbose, :log_path => @log_path, :stdout => stdout, :stderr => stderr)
                    end
  end

  def exist
    be_exist
  end

  def bindir
    @bindir ||= begin
                  dir = tmpdir.join("ey_test_cmds_#{Time.now.to_f}_#{$$}")
                  dir.mkpath
                  dir
                end
  end

  def mock_command(cmd, contents, &block)
    bindir.join(cmd).open('w') do |f|
      f.write contents
      f.chmod(0755)
    end
    with_mocked_commands(&block) if block_given?
  end

  def mock_bundler(failure = false, &block)
    mock_command('bundle', <<-SCRIPT, &block)
#!#{`which ruby`}
puts "Bundling gems"
$stdout.flush
#{failure && '$stderr.puts "bundle install failure"; exit 1'}
    SCRIPT
  end

  def mock_sudo(&block)
    mock_command('sudo', <<-SCRIPT, &block)
#!/bin/bash
echo "$@"
exec "$@"
    SCRIPT
  end

  def with_mocked_commands(&block)
    with_env('PATH' => "#{bindir}:#{ENV['PATH']}", &block)
  end

  def with_env(new_env_vars)
    raise ArgumentError, "with_env takes a block" unless block_given?

    old_env_vars = {}
    new_env_vars.each do |k, v|
      if ENV.has_key?(k)
        old_env_vars[k] = ENV[k]
      end
      ENV[k] = v if v
    end

    yield
  ensure
    new_env_vars.keys.each do |k|
      if old_env_vars.has_key?(k)
        ENV[k] = old_env_vars[k]
      else
        ENV.delete(k)
      end
    end
  end


  def deploy_dir
    @deploy_dir ||= tmpdir.join("serverside-deploy-#{Time.now.to_f}-#{$$}")
  end

  # set up EY::Serverside::Server like we're on a solo
  def test_servers
    @test_servers ||= EY::Serverside::Servers.from_hashes([{:hostname => 'localhost', :roles => %w[solo], :user => ENV['USER']}], test_shell)
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
    mock_bundler(options['bundle_install_fails']) do
      capture do
        EY::Serverside::CLI.start(@argv)
      end
    end
  ensure
    @deployer = EY::Serverside::Deploy.deployer
    @config = EY::Serverside::Deploy.config
  end

  def redeploy_test_application(extra_config = {}, &block)
    raise "Please deploy_test_application first" unless @argv
    bundle_install_fails = extra_config.delete('bundle_install_fails')

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
    mock_bundler(bundle_install_fails) do
      capture do
        EY::Serverside::CLI.start(@argv)
      end
    end
  ensure
    @deployer = EY::Serverside::Deploy.deployer
    @config = EY::Serverside::Deploy.config
  end
end
