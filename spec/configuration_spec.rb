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
      expect(@config.app_name).to eq("app_name")
      expect(@config.environment_name).to eq("env_name")
      expect(@config.account_name).to eq("acc")
      expect(@config.migrate).to eq(nil)
      expect(@config.migrate?).to eq(false)
      expect(@config.branch).to eq("master")
      expect(@config.maintenance_on_migrate).to eq(true)
      expect(@config.maintenance_on_restart).to eq(true)
      expect(@config.required_downtime_stack?).to eq(true)
      expect(@config.framework_env).to eq("production")
      expect(@config.precompile_assets).to eq("detect")
      expect(@config.precompile_assets_inferred?).to eq(true)
      expect(@config.skip_precompile_assets?).to eq(false)
      expect(@config.precompile_assets?).to eq(false)
      expect(@config.asset_roles).to eq([:app_master, :app, :solo])
      expect(@config.user).to eq(ENV['USER'])
      expect(@config.group).to eq(ENV['USER'])
      expect(@config.verbose).to eq(false)
      expect(@config.copy_exclude).to eq([])
      expect(@config.ignore_database_adapter_warning).to eq(false)
      expect(@config.ignore_gemfile_lock_warning).to eq(false)
      expect(@config.bundle_without).to eq(%w[test development])
      expect(@config.extra_bundle_install_options).to eq(%w[--without test development])
      expect(@config.deployed_by).to eq("Automation (User name not available)")
      expect(@config.input_ref).to eq(@config.branch)
      expect(@config.keep_releases).to eq(3)
      expect(@config.keep_failed_releases).to eq(3)
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
    let(:options) do
      { "app" => "serverside" }
    end

    it "uses strategy if set" do
      @config = EY::Serverside::Deploy::Configuration.new(
        options.merge({'strategy' => 'IntegrationSpec', 'git' => 'git@github.com:engineyard/todo.git'})
      )
      capture do # deprecation warning
        expect(@config.source(test_shell)).to be_a_kind_of(EY::Serverside::Source::IntegrationSpec)
      end
      expect(read_output).to include("DEPRECATION WARNING: The configuration key 'strategy' is deprecated in favor of 'source_class'.")
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
        'config' => MultiJson.dump({'custom' => 'custom_from_extra_config', 'maintenance_on_migrate' => 'false', 'precompile_assets' => 'false', 'deployed_by' => 'Martin Emde', 'input_ref' => 'input_branch'})
      })
    end

    it "underrides options with config (directly supplied options take precedence over 'config' options)" do
      expect(@config.maintenance_on_migrate).to eq(false)
      expect(@config.branch).to eq("branch_from_command_line")
    end

    it "corrects command line supplied precompile_assets string (which relies on having a special not-set value of nil, so can't be a boolean)" do
      expect(@config.skip_precompile_assets?).to eq(true)
      expect(@config.precompile_assets?).to eq(false)
      expect(@config.precompile_assets_inferred?).to eq(false)
    end

    it "doesn't require downtime on restart for nginx_passenger" do
      expect(@config.maintenance_on_migrate).to eq(false)
      expect(@config.maintenance_on_restart).to eq(false)
    end

    it "doesn't bundle --without the framework_env" do
      expect(@config.bundle_without).to eq(%w[test])
    end

    it "gets deployed_by and input_ref correct" do
      expect(@config.deployed_by).to eq("Martin Emde")
      expect(@config.input_ref).to eq("input_branch")
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
      expect(@deploy.config.copy_exclude).to eq(['.git'])
    end

    it "falls back to 'config/ey.yml'" do
      write_ey_yml 'config/ey.yml', @yaml_data
      @deploy.load_ey_yml
      expect(@deploy.config.copy_exclude).to eq(['.git'])
    end

    it "loads at lower priority than command line options" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      expect(@deploy.config.migrate?).to eq(false)
    end

    it "loads at lower priority than json config option" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      expect(@deploy.config.branch).to eq('branch_from_command_line')
    end

    it "loads bundle_without from the config, which overrides the default" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      expect(@deploy.config.bundle_without).to eq('only test')
    end

    it "overrides boolean ey.yml only options with --conifg strings" do
      write_ey_yml 'ey.yml', @yaml_data
      @deploy.load_ey_yml
      expect(@deploy.config).not_to be_maintenance_on_migrate
    end
  end
end
