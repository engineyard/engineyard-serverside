require 'spec_helper'

describe EY::Serverside::Deploy::Configuration do
  describe "default options" do
    it "has defaults" do
      @config = EY::Serverside::Deploy::Configuration.new({
        'app' => 'app_name',
        'environment_name' => 'env_name',
        'account_name' => 'acc',
        'framework_env' => 'production',
      })
      @config.app_name.should == "app_name"
      @config.environment_name.should == "env_name"
      @config.account_name.should == "acc"
      @config.migrate.should == nil
      @config.migrate?.should == false
      @config.branch.should == "master"
      @config.maintenance_on_migrate.should == true
      @config.maintenance_on_restart.should == true
      @config.required_downtime_stack?.should == true
      @config.framework_env.should == "production"
      @config.precompile_assets.should == "detect"
      @config.precompile_assets_inferred?.should == true
      @config.skip_precompile_assets?.should == false
      @config.precompile_assets?.should == false
      @config.asset_roles.should == [:app_master, :app, :solo]
      @config.user.should == ENV['USER']
      @config.group.should == ENV['USER']
      @config.verbose.should == false
      @config.copy_exclude.should == []
      @config.ignore_database_adapter_warning.should == false
      @config.bundle_without.should == %w[test development]
      @config.extra_bundle_install_options.should == %w[--without test development]
    end

    it "raises when required options are not given" do
      @config = EY::Serverside::Deploy::Configuration.new({})
      expect { @config.app_name }.to raise_error
      expect { @config.environment_name }.to raise_error
      expect { @config.account_name }.to raise_error
      expect { @config.framework_env }.to raise_error
    end
  end

  context "strategies" do
    let(:options) {
      { "app" => "serverside" }
    }
    it "uses strategy if set" do
      @config = EY::Serverside::Deploy::Configuration.new(
        options.merge({'strategy' => 'IntegrationSpec', 'git' => 'git@github.com:engineyard/todo.git'})
      )
      expect(@config.source(test_shell)).to be_a_kind_of(EY::Serverside::Source::IntegrationSpec)
    end

    it "uses source_class if set" do
      @config = EY::Serverside::Deploy::Configuration.new(
        options.merge({'source_class' => 'IntegrationSpec', 'git' => 'git@github.com:engineyard/todo.git'})
      )
      expect(@config.source(test_shell)).to be_a_kind_of(EY::Serverside::Source::IntegrationSpec)
    end

    it "infers a git source" do
      @config = EY::Serverside::Deploy::Configuration.new(
        options.merge({ 'git' => 'git@github.com:engineyard/todo.git' })
      )
      expect(@config.source(test_shell)).to be_a_kind_of(EY::Serverside::Source::Git)
    end

    it "infers a archive source" do
      @config = EY::Serverside::Deploy::Configuration.new(
        options.merge({'archive' => 'https://github.com/engineyard/todo/archive/master.zip'})
      )

      expect(@config.source(test_shell)).to be_a_kind_of(EY::Serverside::Source::Archive)
    end
  end

  context "command line options" do
    before do
      @config = EY::Serverside::Deploy::Configuration.new({
        'repository_cache' => @tempdir,
        'app' => 'app_name',
        'stack' => 'nginx_passenger',
        'framework_env' => 'development',
        'environment_name' => 'env_name',
        'account_name' => 'acc',
        'branch' => 'branch_from_command_line',
        'config' => MultiJson.dump({'custom' => 'custom_from_extra_config', 'maintenance_on_migrate' => 'false', 'precompile_assets' => 'false'})
      })
    end

    it "underrides options with config (directly supplied options take precedence over 'config' options)" do
      @config.maintenance_on_migrate.should == false
      @config.branch.should == "branch_from_command_line"
    end

    it "corrects command line supplied precompile_assets string (which relies on having a special not-set value of nil, so can't be a boolean)" do
      @config.skip_precompile_assets?.should == true
      @config.precompile_assets?.should == false
      @config.precompile_assets_inferred?.should == false
    end

    it "doesn't require downtime on restart for nginx_passenger" do
      @config.maintenance_on_migrate.should == false
      @config.maintenance_on_restart.should == false
    end

    it "doesn't bundle --without the framework_env" do
      @config.bundle_without.should == %w[test]
    end
  end

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
        'config' => MultiJson.dump({'custom' => 'custom_from_extra_config', 'maintenance_on_migrate' => 'false'})
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
