require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  context "with default production settings" do
    it "precompiles assets when asset compilation is detected" do
      deploy_test_application('assets_detected')
      deploy_dir.join('current', 'precompiled').should exist
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should include("Precompiling assets. ('app/assets' exists, 'public/assets' not found, not disabled in config.)")
    end

    it "precompiles assets, then reuses them on the next deploy if nothing has changed" do
      deploy_test_application('assets_enabled_in_ey_yml')
      deploy_dir.join('current', 'precompiled').should exist
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist

      redeploy_test_application
      deploy_dir.join('current', 'precompiled').should_not exist # doesn't run the task
      deploy_dir.join('current', 'public', 'assets').should exist # but the assets are there
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should =~ %r#Reusing existing assets\. \(configured asset_dependencies unchanged from \w{7}..\w{7}\)#

      redeploy_test_application('config' => {'precompile_unchanged_assets' => 'true'})
      deploy_dir.join('current', 'precompiled').should exist # doesn't run the task
      deploy_dir.join('current', 'public', 'assets').should exist # but the assets are there
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should_not include("Reusing existing assets")
    end

    it "precompile assets again when redeploying a ref with changes" do
      deploy_test_application('assets_enabled_in_ey_yml')
      deploy_dir.join('current', 'precompiled').should exist
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should include("Precompiling assets. (precompile_assets: true)")

      # changing the ref stands in for actually having assets change (see Strategies::IntegrationSpec#same?)
      redeploy_test_application('branch' => 'somenewref')
      deploy_dir.join('current', 'precompiled').should exist # it does runs the task
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should_not =~ %r#Reusing existing assets#
    end

    it "precompile assets when redeploying the same ref, but assets were turned off the first time" do
      deploy_test_application('assets_enabled_in_ey_yml', 'config' => {'precompile_assets' => 'false'})
      deploy_dir.join('current', 'precompiled').should_not exist
      deploy_dir.join('current', 'public', 'assets').should_not exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should_not exist
      read_output.should_not include("Precompiling assets. (precompile_assets: true)")

      # assets will show as unchanged, but it should compile them fresh anyway.
      redeploy_test_application('config' => {'precompile_assets' => 'true'})
      deploy_dir.join('current', 'precompiled').should exist # it does runs the task
      deploy_dir.join('current', 'public', 'assets').should exist
      deploy_dir.join('current', 'public', 'assets', 'compiled_asset').should exist
      read_output.should_not =~ %r#Reusing existing assets#
    end
  end

  context "with asset compilation enabled in ey.yml, despite not otherwise being enabled" do
    before(:all) do
      deploy_test_application('assets_enabled_in_ey_yml')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should exist
      read_output.should include("Precompiling assets. (precompile_assets: true)")
    end
  end

  context "with asset compilation enabled in ey.yml, but asset_roles is set to only :util" do
    before(:all) do
      deploy_test_application('assets_enabled_util_only')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
      read_output.should include("Precompiling assets. (precompile_assets: true)")
    end
  end

  context "with asset compilation enabled in ey.yml, and asset_roles is set to :all" do
    before(:all) do
      deploy_test_application('assets_enabled_all')
    end

    it "precompiles assets" do
      deploy_dir.join('current', 'precompiled').should exist
      read_output.should include("Precompiling assets. (precompile_assets: true)")
    end
  end

  context "with asset support disabled in config/application.rb" do
    before(:all) do
      deploy_test_application('assets_disabled')
    end

    it "does not precompile assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
      read_output.should include("Skipping asset precompilation. ('config/application.rb' disables assets.)")
    end
  end

  context "with asset compilation disabled in ey.yml, despite all other configuration would enable assets" do
    before(:all) do
      deploy_test_application('assets_disabled_in_ey_yml')
    end

    it "does not precompile assets" do
      deploy_dir.join('current', 'precompiled').should_not exist
      read_output.should include("Skipping asset precompilation. (precompile_assets: false)")
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
      deploy_dir.join('current', 'public', 'assets', 'custom_compiled_asset').should exist
      read_output.should include("Skipping asset precompilation. ('public/assets' directory already exists.)")
    end
  end
end
