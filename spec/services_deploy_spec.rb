require 'spec_helper'

describe "Deploying an application with services" do
  let(:shared_services_file) { deploy_dir.join('shared', 'config', 'ey_services_config_deploy.yml') }
  let(:symlinked_services_file) { deploy_dir.join('current', 'config', 'ey_services_config_deploy.yml') }
  let(:services_yml) { {"servicio" => {"foo" => "bar"}}.to_yaml }

  describe "without ey_config" do
    describe "with services" do
      before do
        mock_command('ey-services-setup', "echo '#{services_yml}' > #{shared_services_file}") do
          deploy_test_application('no_ey_config', 'config' => {
            'services_setup_command' => 'ey-services-setup'
          })
        end
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
      mock_command('ey-services-setup', "echo '#{@invalid_services_yml}' > #{shared_services_file}") do
        deploy_test_application('default', 'config' => {
          'services_setup_command' => 'ey-services-setup'
        })
      end
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
      mock_command('ey-services-setup', "echo '#{services_yml}' > #{shared_services_file}") do
        deploy_test_application('default', 'config' => {
          'services_setup_command' => 'ey-services-setup'
        })
      end
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
      mock_command('ey-services-setup', "echo '#{services_yml}' > #{shared_services_file}") do
        deploy_test_application('default', 'config' => {'services_setup_command' => 'ey-services-setup'})
      end
      mock_command('ey-services-setup', "false") do
        redeploy_test_application('config' => {'services_check_command' => 'ey-services-setup'})
      end
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
      mock_command('ey-services-setup', "echo '#{services_yml}' > #{shared_services_file}") do
        deploy_test_application('default', 'config' => {'services_setup_command' => 'ey-services-setup'})
      end
      mock_command('ey-services-setup', "false") do
        redeploy_test_application('config' => {'services_setup_command' => 'ey-services-setup'})
      end

      expect(shared_services_file).to exist
      expect(shared_services_file).not_to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(symlinked_services_file).to exist
      expect(symlinked_services_file).to be_symlink
      expect(shared_services_file.read).to eq("#{services_yml}\n")

      expect(read_output).to include('WARNING: External services configuration not updated')
    end

    it "does not log a warning or symlink a config file when there is no existing services file" do
      mock_command('ey-services-setup', "echo '#{services_yml}' > #{shared_services_file}") do
        deploy_test_application('default', 'config' => {'services_setup_command' => 'ey-services-setup'})
      end
      shared_services_file.delete
      mock_command('ey-services-setup', "false") do
        redeploy_test_application('config' => {'services_setup_command' => 'ey-services-setup'})
      end

      expect(shared_services_file).not_to exist
      expect(symlinked_services_file).not_to exist

      expect(read_output).not_to match(/WARNING/)
    end
  end

  describe "a successful deploy followed by another successful deploy" do
    before do
      mock_command('ey-services-setup', "echo '#{services_yml}' > #{shared_services_file}") do
        deploy_test_application('default', 'config' => {'services_setup_command' => 'ey-services-setup'})
      end
      @new_services_yml = {"servicio" => {"foo" => "bar2"}}.to_yaml
      mock_command('ey-services-setup', "echo '#{@new_services_yml}' > #{shared_services_file}") do
        redeploy_test_application('config' => {'services_setup_command' => 'ey-services-setup'})
      end
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
