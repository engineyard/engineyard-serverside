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
      @deploy_dir.join('current', 'restart').should exist
    end

    it "runs all the hooks" do
      @deploy_dir.join('current', 'before_bundle.ran' ).should exist
      @deploy_dir.join('current', 'after_bundle.ran'  ).should exist
      @deploy_dir.join('current', 'before_migrate.ran').should exist
      @deploy_dir.join('current', 'after_migrate.ran' ).should exist
      @deploy_dir.join('current', 'before_compile_assets.ran').should exist
      @deploy_dir.join('current', 'after_compile_assets.ran' ).should exist
      @deploy_dir.join('current', 'before_symlink.ran').should exist
      @deploy_dir.join('current', 'after_symlink.ran' ).should exist
      @deploy_dir.join('current', 'before_restart.ran').should exist
      @deploy_dir.join('current', 'after_restart.ran' ).should exist
    end
  end

  context "with failing deploy hook" do
    before(:all) do
      begin
        deploy_test_application('hook_fails')
      rescue EY::Serverside::RemoteFailure
      end
    end

    it "retains the failed release" do
      release_name = File.basename(@config.release_path)
      @deploy_dir.join('releases_failed', release_name).should be_directory
    end
  end
end
