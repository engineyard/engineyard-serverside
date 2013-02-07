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

    class Future
      def inspect
        <<-EOM
#{self.class.name} result below: (run with DEBUG=1 to see the full log)
#{result.inspect}
        EOM
      end
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

  config.before(:all) do
    make_tmpdir
    EY::Serverside.dna_json = {}.to_json
  end

  config.after(:all) do
    delete_tmpdir
  end

  class VerboseStringIO < StringIO
    def <<(str)
      if ENV['VERBOSE'] || ENV['DEBUG']
        $stderr << str
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

  def test_shell
    @test_shell ||= begin
                      @log_path = tmpdir.join("serverside-deploy-#{Time.now.to_i}-#{$$}.log")
                      EY::Serverside::Shell.new(:verbose => true, :log_path => @log_path, :stdout => stdout, :stderr => stderr)
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
    EY::Serverside::Servers.from_hashes([{:hostname => 'localhost', :roles => %w[solo], :user => ENV['USER']}])
  end

  # When a repo fixture name is specified, the files found in the specified
  # spec/fixtures/repos dir are copied into the test github repository.
  def deploy_test_application(repo_fixture_name = 'default', extra_config = {}, &block)
    servers = test_servers

    # run a deploy
    @config = EY::Serverside::Deploy::Configuration.new({
      "strategy"      => "IntegrationSpec",
      "deploy_to"     => deploy_dir.to_s,
      "group"         => GROUP,
      "stack"         => 'nginx_passenger',
      "migrate"       => "ruby -e 'puts ENV[\"PATH\"]' > #{deploy_dir}/path-when-migrating",
      'app'           => 'rails31',
      'environment_name' => 'env',
      'account_name'  => 'acc',
      'framework_env' => 'staging',
      'branch'        => 'somebranch',
      'repo'          => FIXTURES_DIR.join('repos', repo_fixture_name)
    }.merge(extra_config))

    # pretend there is a shared bundled_gems directory
    deploy_dir.join('shared', 'bundled_gems').mkpath
    %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
      deploy_dir.join('shared', 'bundled_gems', name).open("w") { |f| f.write("old\n") }
    end

    @binpath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(servers, @config, test_shell)
    yield @deployer if block_given?
    @deployer.deploy
  end

  def redeploy_test_application(&block)
    raise "Please deploy_test_application first" unless @deployer
    yield @deployer if block_given?
    @deployer.deploy
  end
end
