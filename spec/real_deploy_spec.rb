require File.dirname(__FILE__) + '/spec_helper'

module EY::Strategies::IntegrationSpec
  module Helpers

    def update_repository_cache
      cached_copy = File.join(c.shared_path, 'cached-copy')

      FileUtils.mkdir_p(cached_copy)
      Dir.chdir(cached_copy) do
        `echo "this is my file; there are many like it, but this one is mine" > file`
        File.open('Gemfile', 'w') do |f|
          f.write <<-EOF
source :gemcutter

gem "bundler", "~> 1.0.0.rc.6"
gem "rake"
EOF
        end

        File.open("Gemfile.lock", "w") do |f|
          f.write <<-EOF
GEM
  remote: http://rubygems.org/
  specs:
    rake (0.8.7)

PLATFORMS
  ruby

DEPENDENCIES
  bundler (~> 1.0.0.rc.6)
  rake
EOF
        end
      end
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
      "FONDLED THE CODE"
    end

  end
end

describe "deploying an application" do
  class FullTestDeploy < EY::Deploy
    attr_reader :infos, :debugs, :commands

    def initialize(*)
      super
      @infos = []
      @debugs = []
      @commands = []
    end

    # stfu
    def info(msg)
      @infos << msg
    end

    # no really, stfu
    def debug(msg)
      @debugs << msg
    end

    # passwordless sudo is neither guaranteed nor desired
    def sudo(cmd)
      run(cmd)
    end

    def run(cmd)
      # $stderr.puts(cmd)
      @commands << cmd
      super
    end

    # we're probably running this spec under bundler, but a real
    # deploy does not
    def bundle
      my_env = ENV.to_hash

      ENV.delete("BUNDLE_GEMFILE")
      ENV.delete("BUNDLE_BIN_PATH")

      result = super

      ENV.replace(my_env)
      result
    end

    def get_bundler_installer(lockfile)
      installer = super
      installer.options << ' --quiet'   # stfu already!
      installer
    end

  end

  before(:all) do
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Server like we're on a solo
    EY::Server.reset
    EY::Server.add(:hostname => 'localhost', :roles => %w[solo])

    # run a deploy
    config = EY::Deploy::Configuration.new({
        "strategy" => "IntegrationSpec",
        "deploy_to" => @deploy_dir,
        "group" => `id -gn`.strip,
        "stack" => 'nginx_passenger',
        "migrate" => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating"
      })

    $0 = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  it "creates a REVISION file" do
    File.exist?(File.join(@deploy_dir, 'current', 'REVISION')).should be_true
  end

  it "restarts the app servers" do
    File.exist?(File.join(@deploy_dir, 'current', 'tmp', 'restart.txt')).should be_true
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

end
