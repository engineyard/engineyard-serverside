require 'spec_helper'

describe "Deploying a simple application" do
  context "without Bundler" do
    before(:all) do
      deploy_test_application('not_bundled')
    end

    it "creates a REVISION file" do
      @deploy_dir.join('current', 'REVISION').should exist
    end

    it "restarts the app servers" do
      restart = @deploy_dir.join('current', 'restart')
      restart.should exist
      restart.read.chomp.should == %|LANG="en_US.UTF-8" /engineyard/bin/app_rails31 deploy|
    end
  end
end
