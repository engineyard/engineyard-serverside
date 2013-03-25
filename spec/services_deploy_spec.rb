require 'spec_helper'

describe "Deploying an application with services" do
  let(:shared_services_file) { deploy_dir.join('shared', 'config', 'ey_services_config_deploy.yml') }
  let(:symlinked_services_file) { deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml') }
  let(:services_yml) { {"servicio" => {"foo" => "bar"}}.to_yaml }

  describe "without ey_config" do
    describe "with services" do
      before do
        deploy_test_application('no_ey_config', 'config' => {
          'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
        })
      end

      it "warns about missing ey_config" do
        read_stderr.should include("WARNING: Gemfile.lock does not contain ey_config")
      end
    end

    describe "without services" do
      before do
        deploy_test_application('no_ey_config')
      end

      it "works without warnings" do
        read_output.should_not =~ /WARNING/
      end
    end
  end

  describe "deploy with invalid yaml ey_services_config_deploy" do
    before do
      @invalid_services_yml = "42"
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{@invalid_services_yml}' > #{shared_services_file}"
      })
    end

    it "works without warning" do
      shared_services_file.should exist
      shared_services_file.should_not be_symlink
      shared_services_file.read.should == "#{@invalid_services_yml}\n"

      symlinked_services_file.should exist
      symlinked_services_file.should be_symlink
      shared_services_file.read.should == "#{@invalid_services_yml}\n"

      read_output.should_not =~ /WARNING/
    end
  end

  describe "a succesful deploy" do
    before do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
    end

    it "creates and symlinks ey_services_config_deploy.yml" do
      shared_services_file.should exist
      shared_services_file.should_not be_symlink
      shared_services_file.read.should == "#{services_yml}\n"

      symlinked_services_file.should exist
      symlinked_services_file.should be_symlink
      shared_services_file.read.should == "#{services_yml}\n"

      read_output.should_not =~ /WARNING/
    end
  end

  describe "a successful deploy followed by a deploy that can't find the command" do
    before do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
      redeploy_test_application('config' => {
        'services_check_command' => 'false'
      })
    end

    it "silently fails" do
      shared_services_file.should exist
      shared_services_file.should_not be_symlink
      shared_services_file.read.should == "#{services_yml}\n"

      symlinked_services_file.should exist
      symlinked_services_file.should be_symlink
      shared_services_file.read.should == "#{services_yml}\n"

      read_output.should_not =~ /WARNING/
    end

  end

  describe "a successful followed by a deploy that fails to fetch services" do
    it "logs a warning and symlinks the existing config file when there is existing services file" do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
      redeploy_test_application('config' => {'services_setup_command' => 'false'})

      shared_services_file.should exist
      shared_services_file.should_not be_symlink
      shared_services_file.read.should == "#{services_yml}\n"

      symlinked_services_file.should exist
      symlinked_services_file.should be_symlink
      shared_services_file.read.should == "#{services_yml}\n"

      read_output.should include('WARNING: External services configuration not updated')
    end

    it "does not log a warning or symlink a config file when there is no existing services file" do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
      shared_services_file.delete
      redeploy_test_application('config' => {'services_setup_command' => 'false'})

      shared_services_file.should_not exist
      symlinked_services_file.should_not exist

      read_output.should_not =~ /WARNING/
    end
  end

  describe "a successful deploy followed by another successfull deploy" do
    before do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
      @new_services_yml = {"servicio" => {"foo" => "bar2"}}.to_yaml
      redeploy_test_application('config' => {
        'services_setup_command' => "echo '#{@new_services_yml}' > #{shared_services_file}"
      })
    end

    it "replaces the config with the new one (and symlinks)" do
      shared_services_file.should exist
      shared_services_file.should_not be_symlink
      shared_services_file.read.should == "#{@new_services_yml}\n"

      symlinked_services_file.should exist
      symlinked_services_file.should be_symlink
      shared_services_file.read.should == "#{@new_services_yml}\n"

      read_output.should_not =~ /WARNING/
    end
  end

end
