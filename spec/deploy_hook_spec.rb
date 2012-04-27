require 'spec_helper'

describe "deploy hooks" do
  context "successful deploy with all hooks" do
    before(:all) do
      deploy_test_application('hooks')
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

  context "deploy hook API" do

    def deploy_hook(options={})
      config = EY::Serverside::Deploy::Configuration.new(options)
      EY::Serverside::DeployHook.new(config, test_shell)
    end

    context "#run" do
      it "is available" do
        deploy_hook.eval_hook('respond_to?(:run)').should be_true
      end

      it "runs commands like the shell does" do
        ENV['COUNT'] = 'Chocula'
        File.unlink("/tmp/deploy_hook_spec.the_count") rescue nil

        deploy_hook.eval_hook('run("echo $COUNT > /tmp/deploy_hook_spec.the_count")')

        IO.read("/tmp/deploy_hook_spec.the_count").strip.should == "Chocula"
      end

      it "returns true/false to indicate the command's success" do
        deploy_hook.eval_hook('run("true")').should be_true
        deploy_hook.eval_hook('run("false")').should be_false
      end
    end

    context "#sudo" do
      it "is available" do
        deploy_hook.eval_hook('respond_to?(:sudo)').should be_true
      end

      it "runs things with sudo" do
        hook = deploy_hook
        cmd = "sudo sh -l -c 'do it as root'"
        result = EY::Serverside::Shell::CommandResult.new(cmd, 0, "out\nerr")
        hook.callback_context.shell.should_receive(:logged_system).with(cmd).and_return(result)
        hook.eval_hook('sudo("do it as root") || raise("failed")')
      end
    end

    context "capistrano-ish methods" do
      it "has them" do
        deploy_hook.eval_hook('respond_to?(:latest_release)    ').should be_true
        deploy_hook.eval_hook('respond_to?(:previous_release)  ').should be_true
        deploy_hook.eval_hook('respond_to?(:all_releases)      ').should be_true
        deploy_hook.eval_hook('respond_to?(:current_path)      ').should be_true
        deploy_hook.eval_hook('respond_to?(:shared_path)       ').should be_true
        deploy_hook.eval_hook('respond_to?(:release_dir)       ').should be_true
        deploy_hook.eval_hook('respond_to?(:failed_release_dir)').should be_true
        deploy_hook.eval_hook('respond_to?(:release_path)      ').should be_true
      end
    end

    context "access to command line options that should be handed through to the config" do
      before do
        @hook = deploy_hook({'app' => 'app', 'environment_name' => 'env', 'account_name' => 'acc'})
      end

      it "has account_name" do
        @hook.eval_hook('account_name').should == 'acc'
      end

      it "has environment_name" do
        @hook.eval_hook('environment_name').should == 'env'
      end

      it "has app_name" do
        @hook.eval_hook('app_name').should == 'app'
      end
    end

    context "the @node ivar" do
      before(:each) do
        EY::Serverside.dna_json = {
          'instance_role' => 'solo',
          'applications' => {
            'myapp' => {
              'type' => 'rails',
              'branch' => 'master',
            }
          }
        }.to_json
      end

      it "is available" do
        deploy_hook.eval_hook('@node.nil?').should be_false
      end

      it "has indifferent access" do
        deploy_hook.eval_hook('@node[:instance_role] ').should == 'solo'
        deploy_hook.eval_hook('@node["instance_role"]').should == 'solo'
      end

      it "has deep indifferent access" do
        deploy_hook.eval_hook('@node["applications"]["myapp"]["type"]').should == 'rails'
        deploy_hook.eval_hook('@node[:applications]["myapp"][:type]  ').should == 'rails'
        deploy_hook.eval_hook('@node[:applications][:myapp][:type]   ').should == 'rails'
      end
    end

    context "the @configuration ivar" do
      it "is available" do
        deploy_hook.eval_hook('@configuration.nil?').should be_false
      end

      it "has the configuration in it" do
        deploy_hook('bert' => 'ernie').eval_hook('@configuration.bert').should == 'ernie'
      end

      it "can be accessed with method calls, with [:symbols], or ['strings']" do
        deploy_hook('bert' => 'ernie').eval_hook('@configuration.bert   ').should == 'ernie'
        deploy_hook('bert' => 'ernie').eval_hook('@configuration[:bert] ').should == 'ernie'
        deploy_hook('bert' => 'ernie').eval_hook('@configuration["bert"]').should == 'ernie'
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
          deploy_hook.eval_hook("@configuration.has_key?(#{attribute.inspect})").should be_true
        end
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
          hook = deploy_hook(:current_roles => role.split(','), :current_name => name)
          hook.eval_hook("#{code} { 'ran' } == 'ran'")
        end.map do |scenario|
          scenario.compact.join("_")
        end.compact
      end

      it "#on_app_master runs on app masters and solos" do
        where_code_runs_with("on_app_master").should == %w(solo app_master)
      end

      it "#on_app_servers runs on app masters, app slaves, and solos" do
        where_code_runs_with("on_app_servers").should == %w(solo app_master app multi_role,app)
      end

      it "#on_app_servers_and_utilities does what it says on the tin" do
        where_code_runs_with("on_app_servers_and_utilities").should ==
          %w(solo app_master app multi_role,app multi,util util_alpha util_beta util_gamma)
      end

      it "#on_utilities() runs on all utility instances" do
        where_code_runs_with("on_utilities").should ==
          %w(multi,util util_alpha util_beta util_gamma)
      end

      it "#on_utilities('sometype') runs on only utilities of type 'sometype'" do
        where_code_runs_with("on_utilities('alpha')").should == %w(util_alpha)
      end

      it "#on_utilities('type1', 'type2') runs on utilities of both types" do
        where_code_runs_with("on_utilities('alpha', 'beta')").should ==
          %w(util_alpha util_beta)
      end

      it "#on_utilities can be invoked with (['a', 'b']) or ('a', 'b')" do
        where_code_runs_with("on_utilities(%w[alpha beta])").should ==
          where_code_runs_with("on_utilities('alpha', 'beta')")
      end

    end

    context "#syntax_error" do
      it "returns nil for hook files containing valid Ruby syntax" do
        hook_path = File.expand_path('../fixtures/valid_hook.rb', __FILE__)
        deploy_hook.syntax_error(hook_path).should be_nil
      end

      it "returns a brief problem description for hook files containing valid Ruby syntax" do
        hook_path = File.expand_path('../fixtures/invalid_hook.rb', __FILE__)
        error = Regexp.escape("spec/fixtures/invalid_hook.rb:1: syntax error, unexpected '^'")
        deploy_hook.syntax_error(hook_path).should =~ /#{error}/
      end
    end

    context "is compatible with older deploy hook scripts" do
      it "#current_role returns the first role" do
        deploy_hook(:current_roles => %w(a b)).eval_hook('current_role').should == 'a'
      end

      it "has info, warning, debug, logged_system, and access to shell" do
        deploy_hook.eval_hook('respond_to?(:info)         ').should be_true
        deploy_hook.eval_hook('respond_to?(:warning)      ').should be_true
        deploy_hook.eval_hook('respond_to?(:debug)        ').should be_true
        deploy_hook.eval_hook('respond_to?(:logged_system)').should be_true
        deploy_hook.eval_hook('respond_to?(:shell)        ').should be_true
      end
    end
  end
end
