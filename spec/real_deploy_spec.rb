require File.dirname(__FILE__) + '/spec_helper'

module EY::Strategies::IntegrationSpec
  module Helpers

    def update_repository_cache
      cached_copy = File.join(c.shared_path, 'cached-copy')

      FileUtils.mkdir_p(cached_copy)
      Dir.chdir(cached_copy) do
        `echo "this is my file; there are many like it, but this one is mine" > file`
      end
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
      "oh crap, here comes #{revision}"
    end

  end  
end

describe "deploying an application" do


  class FullTestDeploy < EY::Deploy
    def initialize(*)
      super
      @infos = []
      @debugs = []
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

  end

  before(:all) do
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Server like we're on a solo
    EY::Server.all = [{:hostname => 'dontcare', :role => 'solo'}]

    # run a deploy
    config = EY::Deploy::Configuration.new({
        "strategy" => "IntegrationSpec",
        "deploy_to" => @deploy_dir,
        "group" => `id -gn`.strip,
        "stack" => 'nginx_passenger',
      })

    @deployer = FullTestDeploy.new(config)
    @deployer.deploy
  end

  it "creates a REVISION file" do
    File.exist?(File.join(@deploy_dir, 'current', 'REVISION')).should be_true
  end
end
