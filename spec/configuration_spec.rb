require 'spec_helper'

describe EY::Serverside::Deploy::Configuration do
  describe "ey.yml loading" do
    before(:each) do
      @tempdir = `mktemp -d -t ey_yml_spec.XXXXX`.strip
      @config = EY::Serverside::Deploy::Configuration.new({
        'repository_cache' => @tempdir,
        'app' => 'app_name',
        'environment_name' => 'env_name',
        'account_name' => 'acc',
        'migrate' => nil,
        'branch' => 'branch_from_command_line',
        'config' => {'custom' => 'custom_from_extra_config', 'maintenance_on_migrate' => 'false'}.to_json
      })

      @deploy = FullTestDeploy.new(test_servers, @config, test_shell)

      @yaml_data = {
        'environments' => {
          'env_name' => {
            'copy_exclude' => ['.git'],
            'migrate' => true,
            'migration_command' => 'uh oh',
            'branch' => 'branch_from_ey_yml',
            'custom' => 'custom_from_ey_yml',
            'bundle_without' => 'only test',
            'maintenance_on_migrate' => true,
          }
        }
      }
    end

    def write_ey_yml(relative_path, data)
      FileUtils.mkdir_p(File.join(
        @tempdir,
        File.dirname(relative_path)))

      File.open(File.join(@tempdir, relative_path), 'w') do |f|
        f.write data.to_yaml
      end
    end

    it "requires 'ey.yml' and adds any defined methods to the deploy" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      @deploy.config.copy_exclude.should == ['.git']
    end

    it "falls back to 'config/ey.yml'" do
      write_ey_yml 'config/ey.yml', @yaml_data
      @deploy.load_ey_yml
      @deploy.config.copy_exclude.should == ['.git']
    end

    it "loads at lower priority than command line options" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      @deploy.config.migrate?.should == false
    end

    it "loads at lower priority than json config option" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      @deploy.config.branch.should == 'branch_from_command_line'
    end

    it "loads bundle_without from the config, which overrides the default" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      @deploy.config.bundle_without.should == 'only test'
    end

    it "overrides boolean ey.yml only options with --conifg strings" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      @deploy.config.should_not be_maintenance_on_migrate
    end
  end
end
