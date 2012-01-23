require 'spec_helper'

describe "Deploying a Rails 3.1 application" do
  context "with default production settings" do
    before(:all) do
      deploy_test_application
    end

    it "precompiles assets" do
      File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_true
    end
  end

  context "with asset support disabled in its config" do
    before(:all) do
      deploy_test_application(with_assets = false)
    end

    it "does not precompile assets" do
      File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_false
    end
  end

  context "and failing with errors" do
    before(:all) do
      begin
        deploy_test_application(with_assets = false) do
          deploy_dir = File.join(@config.repository_cache, 'deploy')
          FileUtils.mkdir_p(deploy_dir)
          hook = File.join(deploy_dir, 'before_migrate.rb')
          hook_contents = %Q[raise 'aaaaaaahhhhh']
          File.open(hook, 'w') {|f| f.puts(hook_contents) }
          File.chmod(0755, hook)
        end
      rescue EY::Serverside::RemoteFailure
      end
    end

    it "retains the failed release" do
      release_name = File.basename(@config.release_path)
      File.directory?(File.join(@deploy_dir, 'releases_failed', release_name)).should be_true
    end
  end

  context "with existing precompilation in a deploy hook" do
    before(:all) do
      deploy_test_application do
        deploy_dir = File.join(@config.repository_cache, 'deploy')
        FileUtils.mkdir_p(deploy_dir)
        hook = File.join(deploy_dir, 'before_migrate.rb')
        hook_contents = %Q[run 'touch custom_compiled && mkdir public/assets']
        File.open(hook, 'w') {|f| f.puts(hook_contents) }
        File.chmod(0755, hook)
      end
    end

    it "does not replace the public/assets directory" do
      File.exist?(File.join(@deploy_dir, 'current', 'custom_compiled')).should be_true
      File.exist?(File.join(@deploy_dir, 'current', 'precompiled')).should be_false
      File.directory?(File.join(@deploy_dir, 'current', 'public', 'assets')).should be_true
      File.symlink?(File.join(@deploy_dir, 'current', 'public', 'assets')).should be_false
    end
  end
end
