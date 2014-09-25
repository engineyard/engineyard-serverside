require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  context "with default production settings" do
    it "precompiles assets when asset compilation is detected" do
      deploy_test_application('assets_detected')
      expect(deploy_dir.join('current', 'precompiled')).to exist
      expect(deploy_dir.join('current', 'public', 'assets')).to exist
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
      expect(read_output).to include("Precompiling assets. ('app/assets' exists, 'public/assets' not found, not disabled in config.)")
    end

    it "precompiles assets, then reuses them on the next deploy if nothing has changed" do
      deploy_test_application('assets_enabled_in_ey_yml')
      expect(deploy_dir.join('current', 'precompiled')).to exist
      expect(deploy_dir.join('current', 'public', 'assets')).to exist
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist

      redeploy_test_application
      expect(deploy_dir.join('current', 'precompiled')).not_to exist # doesn't run the task
      expect(deploy_dir.join('current', 'public', 'assets')).to exist # but the assets are there
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
      expect(read_output).to match(%r#Reusing existing assets\. \(configured asset_dependencies unchanged from \w{7}..\w{7}\)#)

      redeploy_test_application('config' => {'precompile_unchanged_assets' => 'true'})
      expect(deploy_dir.join('current', 'precompiled')).to exist # doesn't run the task
      expect(deploy_dir.join('current', 'public', 'assets')).to exist # but the assets are there
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
      expect(read_output).not_to include("Reusing existing assets")
    end

    it "precompile assets again when redeploying a ref with changes" do
      deploy_test_application('assets_enabled_in_ey_yml')
      expect(deploy_dir.join('current', 'precompiled')).to exist
      expect(deploy_dir.join('current', 'public', 'assets')).to exist
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
      expect(read_output).to include("Precompiling assets. (precompile_assets: true)")

      # changing the ref stands in for actually having assets change (see Strategies::IntegrationSpec#same?)
      redeploy_test_application('branch' => 'somenewref')
      expect(deploy_dir.join('current', 'precompiled')).to exist # it does runs the task
      expect(deploy_dir.join('current', 'public', 'assets')).to exist
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
      expect(read_output).not_to match(%r#Reusing existing assets#)
    end

    it "precompile assets when redeploying the same ref, but assets were turned off the first time" do
      deploy_test_application('assets_enabled_in_ey_yml', 'config' => {'precompile_assets' => 'false'})
      expect(deploy_dir.join('current', 'precompiled')).not_to exist
      expect(deploy_dir.join('current', 'public', 'assets')).not_to exist
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).not_to exist
      expect(read_output).not_to include("Precompiling assets. (precompile_assets: true)")

      # assets will show as unchanged, but it should compile them fresh anyway.
      redeploy_test_application('config' => {'precompile_assets' => 'true'})
      expect(deploy_dir.join('current', 'precompiled')).to exist # it does runs the task
      expect(deploy_dir.join('current', 'public', 'assets')).to exist
      expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
      expect(read_output).not_to match(%r#Reusing existing assets#)
    end

    %w[cleaning shared private].each do |strategy|
      it "precompiles assets with asset_strategy '#{strategy}', then reuses them on the next deploy if nothing has changed" do
        deploy_test_application('assets_enabled_in_ey_yml', 'config' => {'asset_strategy' => strategy})
        expect(deploy_dir.join('current', 'precompiled')).to exist
        expect(deploy_dir.join('current', 'public', 'assets')).to exist
        expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist

        redeploy_test_application
        expect(deploy_dir.join('current', 'precompiled')).not_to exist # doesn't run the task
        expect(deploy_dir.join('current', 'public', 'assets')).to exist # but the assets are there
        expect(deploy_dir.join('current', 'public', 'assets', 'compiled_asset')).to exist
        expect(read_output).to match(%r#Reusing existing assets\. \(configured asset_dependencies unchanged from \w{7}..\w{7}\)#)
      end
    end
  end

  context "with asset compilation enabled in ey.yml, despite not otherwise being enabled" do
    before(:all) do
      deploy_test_application('assets_enabled_in_ey_yml')
    end

    it "precompiles assets" do
      expect(deploy_dir.join('current', 'precompiled')).to exist
      expect(read_output).to include("Precompiling assets. (precompile_assets: true)")
    end
  end

  context "with asset compilation enabled in ey.yml, but asset_roles is set to only :util" do
    before(:all) do
      deploy_test_application('assets_enabled_util_only')
    end

    it "precompiles assets" do
      expect(deploy_dir.join('current', 'precompiled')).not_to exist
      expect(read_output).to include("Precompiling assets. (precompile_assets: true)")
    end
  end

  context "with asset compilation enabled in ey.yml, and asset_roles is set to :all, and a custom compile command" do
    before(:all) do
      deploy_test_application('assets_enabled_all')
    end

    it "precompiles assets" do
      expect(deploy_dir.join('current', 'custom_compiled')).to exist
      expect(read_output).to include("Precompiling assets. (precompile_assets: true)")
    end
  end

  context "with asset support disabled in config/application.rb" do
    it "does not precompile assets" do
      deploy_test_application('assets_disabled')
      expect(deploy_dir.join('current', 'precompiled')).not_to exist
      expect(read_output).to include("Skipping asset precompilation. ('config/application.rb' disables assets.)")
    end

    it "deploys successfully when application.rb has utf-8 encoding" do
      deploy_test_application('assets_disabled_utf8')
      expect(deploy_dir.join('current', 'precompiled')).not_to exist
      expect(read_output).to include("Skipping asset precompilation. ('config/application.rb' disables assets.)")
    end
  end

  context "with asset compilation disabled in ey.yml, despite all other configuration would enable assets" do
    before(:all) do
      deploy_test_application('assets_disabled_in_ey_yml')
    end

    it "does not precompile assets" do
      expect(deploy_dir.join('current', 'precompiled')).not_to exist
      expect(read_output).to include("Skipping asset precompilation. (precompile_assets: false)")
    end
  end

  context "with existing precompilation in a deploy hook" do
    before(:all) do
      deploy_test_application('assets_in_hook')
    end

    it "does not replace the public/assets directory" do
      expect(deploy_dir.join('current', 'custom_compiled')).to exist
      expect(deploy_dir.join('current', 'precompiled')).not_to exist
      expect(deploy_dir.join('current', 'public', 'assets')).to be_directory
      expect(deploy_dir.join('current', 'public', 'assets')).not_to be_symlink
      expect(deploy_dir.join('current', 'public', 'assets', 'custom_compiled_asset')).to exist
      expect(read_output).to include("Skipping asset precompilation. ('public/assets' directory already exists.)")
    end
  end
end
