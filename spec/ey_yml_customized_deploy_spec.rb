require 'spec_helper'

describe "Deploying an app with ey.yml" do
  before(:all) do
    deploy_test_application('ey_yml', 'migrate' => nil)
  end

  it "excludes copy_excludes from releases" do
    cmd = @deployer.commands.grep(/rsync -aq/).first
    cmd.should include('rsync -aq --exclude=".git" --exclude="README"')
    @deploy_dir.join('current', '.git').should_not exist
    @deploy_dir.join('current', 'README').should_not exist
  end

  it "does not migrate even though ey.yml says migrate: true" do
    read_output.should_not =~ /Migrating/
  end

 it "loads ey.yml at lower priority than command line options" do
    @deploy_dir.join('current', 'REVISION').read.should == "somebranch\n"
  end

  it "loads bundle_without from the config, which overrides the default" do
    cmd = @deployer.commands.grep(/bundle _\S*_ install/).first
    cmd.should include('--without only test')
  end

  it "makes custom variables available to hooks" do
    @deploy_dir.join('current', 'custom_hook').read.should include("custom_from_ey_yml")
  end
end
