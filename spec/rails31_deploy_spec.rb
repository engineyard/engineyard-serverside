require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  context "with default production settings" do
    before(:all) do
      deploy_test_application('assets_enabled')
    end

    it "precompiles assets" do
      @deploy_dir.join('current', 'precompiled').should exist
    end
  end

  context "with asset support disabled in its config" do
    before(:all) do
      deploy_test_application('assets_disabled')
    end

    it "does not precompile assets" do
      @deploy_dir.join('current', 'precompiled').should_not exist
    end
  end

  context "with existing precompilation in a deploy hook" do
    before(:all) do
      deploy_test_application('assets_in_hook')
    end

    it "does not replace the public/assets directory" do
      @deploy_dir.join('current', 'custom_compiled').should exist
      @deploy_dir.join('current', 'precompiled').should_not exist
      @deploy_dir.join('current', 'public', 'assets').should be_directory
      @deploy_dir.join('current', 'public', 'assets').should_not be_symlink
    end
  end
end
