require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  context "with default production settings" do
    before(:all) do
      deploy_test_application('assets_enabled')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should exist
    end
  end

  context "with asset compilation enabled in ey.yml, despite not otherwise being enabled" do
    before(:all) do
      deploy_test_application('assets_enabled_in_ey_yml')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should exist
    end
  end

  context "with asset support disabled in its config" do
    before(:all) do
      deploy_test_application('assets_disabled')
    end

    it "does not precompile assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
    end
  end

  context "with asset compilation disabled in ey.yml, despite all other configuration would enable assets" do
    before(:all) do
      deploy_test_application('assets_disabled_in_ey_yml')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
    end
  end

  context "with existing precompilation in a deploy hook" do
    before(:all) do
      deploy_test_application('assets_in_hook')
    end

    it "does not replace the public/assets directory" do
      deploy_dir.join('current', 'custom_compiled').should exist
      deploy_dir.join('current', 'precompiled').should_not exist
      deploy_dir.join('current', 'public', 'assets').should be_directory
      deploy_dir.join('current', 'public', 'assets').should_not be_symlink
    end
  end

  context "without custom asset roles" do
    before(:all) do
      # I am not sure how to simulate running the deploy on a util server.
      # How would I go about doing that?
      deploy_test_application('assets_enabled')
    end

    it "does not precompile assets on util instances" do
      deploy_dir.join('current', 'precompiled').should_not exist
    end
  end

  context "with custom asset roles" do
    module ::EY::Serverside::RailsAssetSupport
      protected
      def asset_roles
        [:app_master, :app, :solo, :util]
      end
    end

    before(:all) do
      # I am not sure how to simulate running the deploy on a util server.
      # How would I go about doing that?
      deploy_test_application('assets_enabled')
    end

    it "precompiles assets on util instances" do
      deploy_dir.join('current', 'precompiled').should exist
    end
  end
end
