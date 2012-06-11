require 'spec_helper'

describe "Deploying an app with ey.yml" do
  context "--no-migrate" do
    before(:all) do
      deploy_test_application('ey_yml', 'migrate' => nil)
    end

    it "does not migrate even though ey.yml says migrate: true" do
      read_output.should_not =~ /Migrating/
    end

    it "does not enable the maintenance page at all" do
      deploy_dir.join('current','maintenance_disabled').should exist
    end
  end


  context "with migration" do
    before(:all) do
      deploy_test_application('ey_yml')
    end

    it "excludes copy_excludes from releases" do
      cmd = @deployer.commands.grep(/rsync -aq/).first
      cmd.should include('rsync -aq --exclude=".git" --exclude="README"')
      deploy_dir.join('current', '.git').should_not exist
      deploy_dir.join('current', 'README').should_not exist
    end

    it "loads ey.yml at lower priority than command line options" do
      deploy_dir.join('current', 'REVISION').read.should == "somebranch\n"
    end

    it "loads bundle_without from the config, which overrides the default" do
      cmd = @deployer.commands.grep(/bundle _\S*_ install/).first
      cmd.should include('--without only test')
    end

    it "does not enable the maintenance page during migrations" do
      deploy_dir.join('current','maintenance_disabled').should exist
      deploy_dir.join('current','maintenance_enabled').should_not exist
    end

    it "does not remove an existing maintenance page" do
      deploy_dir.join('current','maintenance_disabled').delete
      @deployer.enable_maintenance_page
      deploy_dir.join('shared','system','maintenance.html').should exist
      redeploy_test_application
      read_output.should =~ /Maintenance page is still up./
      deploy_dir.join('shared','system','maintenance.html').should exist
      deploy_dir.join('current','maintenance_disabled').should_not exist
      deploy_dir.join('current','maintenance_enabled').should exist
      @deployer.disable_maintenance_page
      deploy_dir.join('shared','system','maintenance.html').should_not exist
    end

    it "makes custom variables available to hooks" do
      deploy_dir.join('current', 'custom_hook').read.should include("custom_from_ey_yml")
    end

    it "doesn't display the database adapter warning with ignore_database_adapter_warning: true" do
      read_output.should_not =~ /WARNING/
    end
  end

  context "with a different ey.yml" do
    before(:all) do
      deploy_test_application('ey_yml_alt')
    end

    it "always installs maintenance pages" do
      deploy_dir.join('current','maintenance_enabled').should exist
      deploy_dir.join('current','maintenance_disabled').should_not exist
    end

    it "displays the database adapter warning without ignore_database_adapter_warning" do
      read_output.should =~ /WARNING: Gemfile.lock does not contain a recognized database adapter./
    end
  end
end
