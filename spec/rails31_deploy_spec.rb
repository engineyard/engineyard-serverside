require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  context "with default production settings" do
    it "precompiles assets, then reuses them on the next deploy if nothing has changed" do
      deploy_test_application('assets_enabled')
      deploy_dir.join('current', 'precompiled').should exist
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should include("Attempting Rails asset precompilation. (found directory: 'app/assets')")

      redeploy_test_application
      deploy_dir.join('current', 'precompiled').should_not exist # doesn't run the task
      deploy_dir.join('current', 'public', 'assets').should exist # but the assets are there
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should include("Reusing existing assets. (assets appear to be unchanged)")
    end

    it "precompile assets again when redeploying a ref with changes" do
      deploy_test_application('assets_enabled')
      deploy_dir.join('current', 'precompiled').should exist
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should include("Attempting Rails asset precompilation. (found directory: 'app/assets')")

      # changing the ref stands in for actually having assets change (see Strategies::IntegrationSpec#same?)
      redeploy_test_application('branch' => 'somenewref')
      deploy_dir.join('current', 'precompiled').should exist # it does runs the task
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should_not include("Reusing existing assets. (assets appear to be unchanged)")
    end
  end

  context "with asset compilation enabled in ey.yml, despite not otherwise being enabled" do
    before(:all) do
      deploy_test_application('assets_enabled_in_ey_yml')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should exist
      read_output.should include("Precompiling assets. (enabled in config)")
    end
  end

  context "with asset compilation enabled in ey.yml, but asset_roles is set to only :util" do
    before(:all) do
      deploy_test_application('assets_enabled_util_only')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
      read_output.should include("Precompiling assets. (enabled in config)")
    end
  end

  context "with asset compilation enabled in ey.yml, and asset_roles is set to :all" do
    before(:all) do
      deploy_test_application('assets_enabled_all')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should exist
      read_output.should include("Precompiling assets. (enabled in config)")
    end
  end

  context "with asset support disabled in its config" do
    before(:all) do
      deploy_test_application('assets_disabled')
    end

    it "does not precompile assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
      read_output.should include("Skipping asset compilation. (application.rb has disabled asset compilation)")
    end
  end

  context "with asset compilation disabled in ey.yml, despite all other configuration would enable assets" do
    before(:all) do
      deploy_test_application('assets_disabled_in_ey_yml')
    end

    it "does not precompile assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
      read_output.should include("Skipping asset precompilation. (disabled in config)")
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
      read_output.should include("Skipping asset compilation. Already compiled. (found directory: 'public/assets')")
    end
  end
end
