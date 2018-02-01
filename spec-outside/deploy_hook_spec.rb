require 'spec_helper'

describe "deploy hooks" do
  context "successful deploy with all hooks" do
    before(:all) do
      deploy_test_application('hooks')
    end

    it "runs all the hooks" do
      expect(deploy_dir.join('current', 'before_deploy.ran' )).to exist
      expect(deploy_dir.join('current', 'before_bundle.ran' )).to exist
      expect(deploy_dir.join('current', 'after_bundle.ran'  )).to exist
      expect(deploy_dir.join('current', 'before_migrate.ran')).to exist
      expect(deploy_dir.join('current', 'after_migrate.ran' )).to exist
      expect(deploy_dir.join('current', 'before_compile_assets.ran')).to exist
      expect(deploy_dir.join('current', 'after_compile_assets.ran' )).to exist
      expect(deploy_dir.join('current', 'before_symlink.ran')).to exist
      expect(deploy_dir.join('current', 'after_symlink.ran' )).to exist
      expect(deploy_dir.join('current', 'before_restart.ran')).to exist
      expect(deploy_dir.join('current', 'after_restart.ran' )).to exist
      expect(deploy_dir.join('current', 'after_deploy.ran'  )).to exist
    end
  end

  context "with failing deploy hook" do
    before(:all) do
      begin
        deploy_test_application('hook_fails', :verbose => false)
      rescue EY::Serverside::RemoteFailure
      end
    end

    it "prints the failure to the log even when non-verbose" do
      out = read_output
      expect(out).to match(%r|FATAL: Exception raised in deploy hook .*/deploy/before_deploy.rb.|)
      expect(out).to match(%r|RuntimeError:.*Hook failing in \(eval\)|)
      expect(out).to match(%r|Please fix this error before retrying.|)
    end

    it "retains the failed release" do
      release_name = @config.paths.active_release.basename
      expect(deploy_dir.join('releases_failed', release_name)).to be_directory
    end
  end

  context "with an executable for a deploy hook" do
    before(:all) do
      deploy_test_application('executable_hooks')
    end

    it 'runs the hook' do
      expect(deploy_dir.join('current', 'before_restart.ran')).to exist
    end
  end

  context "with a non-executable, but correctly named deploy hook" do
    before(:all) do
      deploy_test_application('executable_hooks_not_executable')
    end

    it 'does not run the hook' do
      expect(deploy_dir.join('current', 'before_restart.ran')).not_to exist
    end

    it 'outputs a message about the hook not being executable' do
      expect(read_output).to match(%r|Skipping.*deploy hook.*not executable|)
    end
  end

  context "deploy hook API" do
    def deploy_hook(options={})
      config = EY::Serverside::Configuration.new({
        'app' => 'app_name',
        'framework_env' => 'staging',
        'current_roles' => ['solo'],
        'deploy_to'     => deploy_dir.to_s,
      }.merge(options))
      # setup to run hooks since a deploy hasn't happened
      config.paths.new_release!
      config.paths.active_release.mkpath
      EY::Serverside::DeployHook.new(config, test_shell, 'fake_test_hook')
    end

    context "#run" do
      it "is available" do
        expect(deploy_hook.eval_hook('respond_to?(:run)')).to be_truthy
      end

      it "runs commands like the shell does" do
        ENV['COUNT'] = 'Chocula'
        File.unlink("/tmp/deploy_hook_spec.the_count") rescue nil

        deploy_hook.eval_hook('run("echo $COUNT > /tmp/deploy_hook_spec.the_count")')

        expect(IO.read("/tmp/deploy_hook_spec.the_count").strip).to eq("Chocula")
      end

      it "returns true/false to indicate the command's success" do
        expect(deploy_hook.eval_hook('run("true")')).to be_truthy
        expect(deploy_hook.eval_hook('run("false")')).to be_falsey
      end

      it "raises when the bang method alternative is used" do
        expect {
          deploy_hook.eval_hook('run!("false")')
        }.to raise_error(RuntimeError)
        out = read_output
        expect(out).to match(%r|FATAL: Exception raised in deploy hook .*/deploy/fake_test_hook.rb.|)
        expect(out).to match(%r|RuntimeError: .*run!.*Command failed. false|)
        expect(out).to match(%r|Please fix this error before retrying.|)
      end
    end

    context "#sudo" do
      it "is available" do
        expect(deploy_hook.eval_hook('respond_to?(:sudo)')).to be_truthy
      end

      it "runs things with sudo" do
        hook = deploy_hook
        mock_sudo do
          hook.eval_hook('sudo("true") || raise("failed")')
        end
      end

      it "raises when the bang method alternative is used" do
        hook = deploy_hook
        mock_sudo do
          expect {
            hook.eval_hook('sudo!("false")')
          }.to raise_error(RuntimeError)
        end
        out = read_output
        expect(out).to match(%r|FATAL: Exception raised in deploy hook .*/deploy/fake_test_hook.rb.|)
        expect(out).to match(%r|RuntimeError: .*sudo!.*Command failed. false|)
        expect(out).to match(%r|Please fix this error before retrying.|)
      end
    end

    context "capistrano-ish methods" do
      it "has them" do
        expect(deploy_hook.eval_hook('respond_to?(:latest_release)    ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:previous_release)  ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:all_releases)      ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:current_path)      ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:shared_path)       ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:release_dir)       ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:failed_release_dir)')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:release_path)      ')).to be_truthy
      end

      it "shows a deprecation warning that asks you to use config to access these variables" do
        expect(deploy_hook.eval_hook('shared_path.nil?')).to be_falsey
        out = read_output
        expect(out).to include("Use of `shared_path` (via method_missing) is deprecated in favor of `config.shared_path` for improved error messages and compatibility.")
        expect(out).to match(%r|in .*/deploy/fake_test_hook.rb|)
      end
    end

    context "access to command line options that should be handed through to the config" do
      before do
        @hook = deploy_hook({'app' => 'app', 'environment_name' => 'env', 'account_name' => 'acc'})
      end

      it "has account_name" do
        expect(@hook.eval_hook('account_name')).to eq('acc')
      end

      it "has environment_name" do
        expect(@hook.eval_hook('environment_name')).to eq('env')
      end

      it "has app_name" do
        expect(@hook.eval_hook('app_name')).to eq('app')
      end
    end

    context "node" do
      before(:each) do
        EY::Serverside.dna_json = MultiJson.dump({
          'instance_role' => 'solo',
          'applications' => {
            'myapp' => {
              'type' => 'rails',
              'branch' => 'master',
            }
          }
        })
      end

      it "is deprecated through the @node ivar" do
        expect(deploy_hook.eval_hook('@node.nil?')).to be_falsey
        out = read_output
        expect(out).to match(%r|Use of `@node` in deploy hooks is deprecated.|)
        expect(out).to match(%r|Please use `config.node`, which provides access to the same object.|)
        expect(out).to match(%r|.*/deploy/fake_test_hook.rb|)
      end

      it "is available" do
        expect(deploy_hook.eval_hook('config.node.nil?')).to be_falsey
      end

      it "has indifferent access" do
        expect(deploy_hook.eval_hook('config.node[:instance_role] ')).to eq('solo')
        expect(deploy_hook.eval_hook('config.node["instance_role"]')).to eq('solo')
      end

      it "has deep indifferent access" do
        expect(deploy_hook.eval_hook('config.node["applications"]["myapp"]["type"]')).to eq('rails')
        expect(deploy_hook.eval_hook('config.node[:applications]["myapp"][:type]  ')).to eq('rails')
        expect(deploy_hook.eval_hook('config.node[:applications][:myapp][:type]   ')).to eq('rails')
      end
    end

    context "config" do
      it "is available" do
        expect(deploy_hook.eval_hook('config.nil?')).to be_falsey
      end

      it "is deprecated through the @configuration ivar" do
        expect(deploy_hook.eval_hook('@configuration.nil?')).to be_falsey
        out = read_output
        expect(out).to match(%r|Use of `@configuration` in deploy hooks is deprecated.|)
        expect(out).to match(%r|Please use `config`, which provides access to the same object.|)
        expect(out).to match(%r|.*/deploy/fake_test_hook.rb|)
      end

      it "has the configuration in it" do
        expect(deploy_hook('bert' => 'ernie').eval_hook('config.bert')).to eq('ernie')
      end

      it "can be accessed with method calls, with [:symbols], or ['strings']" do
        expect(deploy_hook('bert' => 'ernie').eval_hook('config.bert   ')).to eq('ernie')
        expect(deploy_hook('bert' => 'ernie').eval_hook('config[:bert] ')).to eq('ernie')
        expect(deploy_hook('bert' => 'ernie').eval_hook('config["bert"]')).to eq('ernie')
      end

      [:repository_cache,
        :release_path,
        :branch,
        :shared_path,
        :deploy_to,
        :user,
        :revision,
        :environment].each do |attribute|
        it "has the #{attribute.inspect} attribute for compatibility with chef-deploy" do
          expect(deploy_hook.eval_hook("config.has_key?(#{attribute.inspect})")).to be_truthy
        end
      end
    end

    context "environment variables" do
      it "sets the framework env variables" do
        expect(deploy_hook('framework_env' => 'production').eval_hook("ENV['RAILS_ENV']")).to eq('production')
        expect(deploy_hook('framework_env' => 'production').eval_hook("ENV['RACK_ENV'] ")).to eq('production')
        expect(deploy_hook('framework_env' => 'production').eval_hook("ENV['MERB_ENV'] ")).to eq('production')
        expect(deploy_hook('framework_env' => 'production').eval_hook("ENV['NODE_ENV'] ")).to eq('production')
      end
    end

    context "has methods to run code only on certain instances" do
      def scenarios
        [
          ['solo'          ],
          ['app_master'    ],
          ['app'           ],
          ['db_master'     ],
          ['db_slave'      ],
          ['multi_role,app'],
          ['multi,util'    ],
          ['util',         'alpha' ],
          ['util',         'beta'  ],
          ['util',         'gamma' ],
        ]
      end

      def where_code_runs_with(code)
        scenarios.select do |role, name|
          hook = deploy_hook('current_roles' => role.split(','), 'current_name' => name)
          hook.eval_hook("#{code} { 'ran' } == 'ran'")
        end.map do |scenario|
          scenario.compact.join("_")
        end.compact
      end

      it "#on_app_master runs on app masters and solos" do
        expect(where_code_runs_with("on_app_master")).to eq(%w(solo app_master))
      end

      it "#on_app_servers runs on app masters, app slaves, and solos" do
        expect(where_code_runs_with("on_app_servers")).to eq(%w(solo app_master app multi_role,app))
      end

      it "#on_app_servers_and_utilities does what it says on the tin" do
        expect(where_code_runs_with("on_app_servers_and_utilities")).to eq(
          %w(solo app_master app multi_role,app multi,util util_alpha util_beta util_gamma)
        )
      end

      it "#on_utilities() runs on all utility instances" do
        expect(where_code_runs_with("on_utilities")).to eq(
          %w(multi,util util_alpha util_beta util_gamma)
        )
      end

      it "#on_utilities('sometype') runs on only utilities of type 'sometype'" do
        expect(where_code_runs_with("on_utilities('alpha')")).to eq(%w(util_alpha))
      end

      it "#on_utilities('type1', 'type2') runs on utilities of both types" do
        expect(where_code_runs_with("on_utilities('alpha', 'beta')")).to eq(
          %w(util_alpha util_beta)
        )
      end

      it "#on_utilities can be invoked with (['a', 'b']) or ('a', 'b')" do
        expect(where_code_runs_with("on_utilities(%w[alpha beta])")).to eq(
          where_code_runs_with("on_utilities('alpha', 'beta')")
        )
      end
    end

    context "#syntax_error" do
      it "returns nil for hook files containing valid Ruby syntax" do
        hook_path = File.expand_path('../fixtures/valid_hook.rb', __FILE__)
        expect(deploy_hook.syntax_error(hook_path)).to be_nil
      end

      it "returns a brief problem description for hook files containing valid Ruby syntax" do
        hook_path = File.expand_path('../fixtures/invalid_hook.rb', __FILE__)
        error = Regexp.escape("spec/fixtures/invalid_hook.rb:1: syntax error, unexpected '^'")
        expect(deploy_hook.syntax_error(hook_path)).to match(/#{error}/)
      end
    end

    context "errors in hooks" do
      it "shows the error in a helpful way" do
        expect {
          deploy_hook.eval_hook('methedo_no_existo')
        }.to raise_error(NameError)
        out = read_output
        expect(out).to match(%r|FATAL: Exception raised in deploy hook .*/deploy/fake_test_hook.rb.|)
        expect(out).to match(%r|NameError: undefined local variable or method `methedo_no_existo' for|)
        expect(out).to match(%r|Please fix this error before retrying.|)
      end
    end

    context "is compatible with older deploy hook scripts" do
      it "#current_role returns the first role" do
        expect(deploy_hook('current_roles' => %w(a b)).eval_hook('current_role')).to eq('a')
      end

      it "has info, warning, debug, logged_system, and access to shell" do
        expect(deploy_hook.eval_hook('respond_to?(:info)         ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:warning)      ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:debug)        ')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:logged_system)')).to be_truthy
        expect(deploy_hook.eval_hook('respond_to?(:shell)        ')).to be_truthy
      end
    end
  end
end
