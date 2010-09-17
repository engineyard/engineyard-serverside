require File.dirname(__FILE__) + '/spec_helper'

describe "Deploying" do
  include FullDeployHelpers

  shared_examples_for "all deploys" do
    it "creates a REVISION file" do
      File.exist?(File.join(@deploy_dir, 'current', 'REVISION')).should be_true
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

  describe "on appcloud" do
    describe "using nginx_passenger" do
      before(:all) {
        @deploy_config = { "stack" => "nginx_passenger" }
        @deployer = run_test_deploy
      }

      it_should_behave_like "all deploys"

      it "restarts the app servers" do
        File.exist?(File.join(@deploy_dir, 'current', 'tmp', 'restart.txt')).should be_true
      end
    end

    describe "using nginx_mongrel" do
      before(:all) {
        @deploy_config = { "stack" => "nginx_mongrel", "app" => "mine" }
        @deployer = run_test_deploy
      }

      it_should_behave_like "all deploys"

      it "restarts the app servers using monit" do
        monit_cmd = @deployer.commands.grep(/^monit/).first
        monit_cmd.should == "monit restart all -g #{@deploy_config['app']}"
        @deployer.command_roles[monit_cmd].should == [ :app_master, :app, :solo ]
      end

      it "uses a maintenance page when migrating" do
        maint_page_cmds = @deployer.commands.grep(/maintenance/)

        # TODO: Kind of pedestrian tests, could be better
        maint_page_cmds.grep(/^cp/).size.should == 1
        maint_page_cmds.grep(/^rm/).size.should == 1

        maint_page_cmds.each { |c|
          @deployer.command_roles[c].should == [ :app_master, :app, :solo ]
        }
      end
    end

    describe "using nginx_unicorn" do
      before(:all) {
        @deploy_config = { "stack" => "nginx_unicorn", "app" => "rainbowfarts" }
        @deployer = run_test_deploy
      }

      it_should_behave_like "all deploys"

      it "restarts the app servers" do
        restart_cmd = @deployer.commands.grep(%r!/engineyard/bin/app_!).first
        restart_cmd.should == "/engineyard/bin/app_#{@deploy_config['app']} deploy"
      end
    end
  end
end
