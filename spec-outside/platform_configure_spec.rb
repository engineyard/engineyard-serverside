require 'spec_helper'

describe "Deploying an application with platform configure command" do
  describe "configure script does not exist" do
    before do
      @releases_failed = deploy_dir.join('releases_failed')
      deploy_test_application('default')
    end

    it "works without warning" do
      expect(read_output).not_to match(/WARNING/)

      expect(@releases_failed).not_to exist
    end
  end

  describe "a succesful deploy" do
    before do
      @releases_failed = deploy_dir.join('releases_failed')
      ENV['EY_SERVERSIDE_CONFIGURE_COMMAND'] = "echo platform_configure_command_ran >&2"
      deploy_test_application('default')
    end

    after do
      ENV.delete('EY_SERVERSIDE_CONFIGURE_COMMAND')
    end

    it "runs the configure_command during deploy and finishes successfully" do
      expect(read_output).to match(/platform_configure_command_ran/)

      expect(@releases_failed).not_to exist

      restart = deploy_dir.join('current', 'restart')
      expect(restart).to exist
    end
  end

  describe "a failed configure command" do

    before do
      ENV['EY_SERVERSIDE_CONFIGURE_COMMAND'] = "echo platform_configure_command_failed >&2 && false"
    end

    after do
      ENV.delete('EY_SERVERSIDE_CONFIGURE_COMMAND')
    end

    it "aborts the deplo when it fails, preventing the app from being restarted" do
      @releases_failed = deploy_dir.join('releases_failed')
      expect(@releases_failed).not_to exist

      begin
        deploy_test_application('default')
      rescue
      end
      expect(read_output).to match(/platform_configure_command_failed/)

      expect(@releases_failed.entries).not_to be_empty
    end
  end
end
