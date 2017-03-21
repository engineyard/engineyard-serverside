require 'spec_helper'

describe "Deploying an app with ey.yml" do
  context "--no-migrate" do
    before(:all) do
      deploy_test_application('ey_yml', 'migrate' => nil)
    end

    it "does not migrate even though ey.yml says migrate: true" do
      expect(read_output).not_to match(/Migrating/)
    end

    it "does not enable the maintenance page at all" do
      expect(deploy_dir.join('current','maintenance_disabled')).to exist
    end
  end


  context "with migration" do
    before(:all) do
      deploy_test_application('ey_yml')
    end

    it "excludes copy_excludes from releases" do
      cmd = @deployer.commands.grep(/rsync -aq/).first
      expect(cmd).to include('rsync -aq --exclude=".git" --exclude="README"')
      expect(deploy_dir.join('current', '.git')).not_to exist
      expect(deploy_dir.join('current', 'README')).not_to exist
    end

    it "loads ey.yml at lower priority than command line options" do
      expect(deploy_dir.join('current', 'REVISION').read).to eq("somebranch\n")
    end

    it "loads bundle_without from the config, which overrides the default (and 'defaults:' in ey.yml)" do
      cmd = @deployer.commands.grep(/bundle _\S*_ install/).first
      expect(cmd).to include('--without only test')
    end

    it "does not enable the maintenance page during migrations" do
      expect(deploy_dir.join('current','maintenance_disabled')).to exist
      expect(deploy_dir.join('current','maintenance_enabled')).not_to exist
    end

    it "does not remove an existing maintenance page" do
      maintenance = EY::Serverside::Maintenance.new(test_servers, @config, test_shell)
      deploy_dir.join('current','maintenance_disabled').delete
      maintenance.manually_enable
      expect(deploy_dir.join('shared','system','maintenance.html')).to exist
      redeploy_test_application
      expect(read_output).to match(/Maintenance page is still up./)
      expect(deploy_dir.join('shared','system','maintenance.html')).to exist
      expect(deploy_dir.join('current','maintenance_disabled')).not_to exist
      expect(deploy_dir.join('current','maintenance_enabled')).to exist
      maintenance.manually_disable
      expect(deploy_dir.join('shared','system','maintenance.html')).not_to exist
    end

    it "makes custom variables available to hooks" do
      expect(deploy_dir.join('current', 'custom_hook').read).to include("custom_from_ey_yml")
    end

    it "doesn't display the database adapter warning with ignore_database_adapter_warning: true" do
      expect(read_output).not_to match(/WARNING/)
    end
  end

  context "with a different ey.yml" do
    before(:all) do
      deploy_test_application('ey_yml_alt') do
        deploy_dir.join('shared','config').mkpath
        deploy_dir.join('shared','config','database.yml').open('w') { |f| f << 'something' }
      end
    end

    it "always installs maintenance pages" do
      expect(deploy_dir.join('current','maintenance_enabled')).to exist
      expect(deploy_dir.join('current','maintenance_disabled')).not_to exist
    end

    it "displays the database adapter warning without ignore_database_adapter_warning" do
      expect(read_output).to match(/WARNING: Gemfile.lock does not contain a recognized database adapter./)
    end
  end

  context "with nodatabase.yml" do
    before(:all) do
      deploy_test_application('ey_yml_alt') do
        deploy_dir.join('shared','config').mkpath
        deploy_dir.join('shared','config','nodatabase.yml').open('w') { |f| f << 'something' }
      end

    end

    it "doesn't display the database adapter warning" do
      expect(read_output).not_to match(/WARNING: Gemfile.lock does not contain a recognized database adapter./)
    end
  end
end
