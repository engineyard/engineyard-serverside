require 'spec_helper'

describe "Rolling back" do
  context "without bundler" do
    before(:all) do
      deploy_test_application('not_bundled', 'migrate' => nil)
      @good_revision = deploy_dir.join('current', 'REVISION').read.strip
      deploy_dir.join('current', 'REVISION').should exist
      deploy_dir.join('current', 'restart').delete
      deploy_test_application('not_bundled', 'migrate' => nil)
      deploy_dir.join('current', 'REVISION').should exist
      deploy_dir.join('current', 'restart').delete
    end

    it "rolls back to the older deploy" do
      releases = @deployer.config.paths.all_releases
      releases.size.should == 2
      good_release = releases.first
      bad_release = releases.last

      @deployer.rollback
      out = read_output
      out.should =~ /Rolling back to previous release.*#{@good_revision}/
      out.should =~ /Restarting with previous release./
      out.should =~ /Finished rollback/

      deploy_dir.join('current', 'restart').should exist
      bad_release.should_not exist
      good_release.join('restart').should exist
    end
  end

  context "with complex config" do
    before(:all) do
      deploy_test_application('ey_yml', 'migrate' => nil)
      @good_revision = deploy_dir.join('current', 'REVISION').read.strip
      deploy_dir.join('current', 'REVISION').should exist
      deploy_dir.join('current', 'restart').delete
      deploy_test_application('ey_yml', 'migrate' => nil)
      deploy_dir.join('current', 'REVISION').should exist
      deploy_dir.join('current', 'restart').delete
    end

    it "rolls back to the older deploy" do
      releases = @deployer.config.paths.all_releases
      releases.size.should == 2
      good_release = releases.first
      bad_release = releases.last

      @deployer.rollback
      out = read_output
      out.should =~ /Rolling back to previous release.*#{@good_revision}/
      out.should =~ /Restarting with previous release./
      out.should =~ /Finished rollback/

      deploy_dir.join('current', 'restart').should exist
      bad_release.should_not exist
      good_release.join('restart').should exist
    end
  end
end
