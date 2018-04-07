require 'spec_helper'

describe "Deploying an application with services" do
  let(:shared_services_file) { deploy_dir.join('shared', 'config', 'ey_services_config_deploy.yml') }
  let(:symlinked_services_file) { deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml') }
  let(:services_yml) { {"servicio" => {"foo" => "bar"}}.to_yaml }

  describe "without ey_config" do
    describe "with services and disabled ey_config warnings" do
      before do
        deploy_test_application('no_ey_config_no_warning', 'config' => {
          'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
        })
      end

      it "no warns about missing ey_config" do
        expect(read_stderr).not_to include("WARNING: Gemfile.lock does not contain ey_config")
      end
    end

    describe "with services" do
      before do
        deploy_test_application('no_ey_config', 'config' => {
          'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
        })
      end

      it "warns about missing ey_config" do
        expect(read_stderr).to include("WARNING: Gemfile.lock does not contain ey_config")
      end
    end

    describe "without services" do
      before do
        deploy_test_application('no_ey_config')
      end

      it "works without warnings" do
        expect(read_output).not_to match(/WARNING/)
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
      expect(shared_services_file).to exist
      expect(shared_services_file).not_to be_symlink
      expect(shared_services_file.read).to eq("#{@invalid_services_yml}\n")

      expect(symlinked_services_file).to exist
      expect(symlinked_services_file).to be_symlink
      expect(shared_services_file.read).to eq("#{@invalid_services_yml}\n")

      expect(read_output).not_to match(/WARNING/)
    end
  end

  describe "a succesful deploy" do
    before do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
    end

    it "creates and symlinks ey_services_config_deploy.yml" do
      expect(shared_services_file).to exist
      expect(shared_services_file).not_to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(symlinked_services_file).to exist
      expect(symlinked_services_file).to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(read_output).not_to match(/WARNING/)
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
      expect(shared_services_file).to exist
      expect(shared_services_file).not_to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(symlinked_services_file).to exist
      expect(symlinked_services_file).to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(read_output).not_to match(/WARNING/)
    end

  end

  describe "a successful followed by a deploy that fails to fetch services" do
    it "logs a warning and symlinks the existing config file when there is existing services file" do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
      redeploy_test_application('config' => {'services_setup_command' => 'false'})

      expect(shared_services_file).to exist
      expect(shared_services_file).not_to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(symlinked_services_file).to exist
      expect(symlinked_services_file).to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(read_output).to include('WARNING: External services configuration not updated')
    end

    it "does not log a warning or symlink a config file when there is no existing services file" do
      deploy_test_application('default', 'config' => {
        'services_setup_command' => "echo '#{services_yml}' > #{shared_services_file}"
      })
      shared_services_file.delete
      redeploy_test_application('config' => {'services_setup_command' => 'false'})

      expect(shared_services_file).not_to exist
      expect(symlinked_services_file).not_to exist

      expect(read_output).not_to match(/WARNING/)
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
      expect(shared_services_file).to exist
      expect(shared_services_file).not_to be_symlink
      expect(shared_services_file.read).to eq("#{@new_services_yml}\n")

      expect(symlinked_services_file).to exist
      expect(symlinked_services_file).to be_symlink
      expect(shared_services_file.read).to eq("#{@new_services_yml}\n")

      expect(read_output).not_to match(/WARNING/)
    end
  end

end
