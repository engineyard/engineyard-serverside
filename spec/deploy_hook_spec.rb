require File.dirname(__FILE__) + '/spec_helper'

describe "the deploy-hook API" do
  before(:each) do
    @hook = EY::DeployHook.new(options)
    @callback_context = EY::DeployHook::CallbackContext.new(@hook.config)
  end

  def run_hook(options={}, &blk)
    raise ArgumentError unless block_given?
    options.each do |k, v|
      @callback_context.configuration[k] = v
    end

    # The hooks on the filesystem are run by passing a string to
    # context.instance_eval, not a block. However, using a block
    # should allow us to get the same degree of test coverage and
    # still let us have things like syntax checking work on this spec
    # file.
    @callback_context.instance_eval(&blk)
  end

  context "#run" do
    it "is available" do
      run_hook { respond_to?(:run) }.should be_true
    end

    it "runs commands like the shell does" do
      ENV['COUNT'] = 'Chocula'
      File.unlink("/tmp/deploy_hook_spec.the_count") rescue nil

      run_hook { run("echo $COUNT > /tmp/deploy_hook_spec.the_count") }

      IO.read("/tmp/deploy_hook_spec.the_count").strip.should == "Chocula"
    end

    it "returns true/false to indicate the command's success" do
      run_hook { run("true") }.should be_true
      run_hook { run("false") }.should be_false
    end
  end

  context "#sudo" do
    it "is available" do
      run_hook { respond_to?(:sudo) }.should be_true
    end

    it "runs things with sudo" do
      @callback_context.should_receive(:system).with("sudo sh -l -c 'do it as root'").and_return(true)

      run_hook { sudo("do it as root") }
    end
  end

  context "capistrano-ish methods" do
    it "has them" do
      run_hook { respond_to?(:latest_release)   }.should be_true
      run_hook { respond_to?(:previous_release) }.should be_true
      run_hook { respond_to?(:all_releases)     }.should be_true
      run_hook { respond_to?(:current_path)     }.should be_true
      run_hook { respond_to?(:shared_path)      }.should be_true
      run_hook { respond_to?(:release_dir)      }.should be_true
      run_hook { respond_to?(:release_path)     }.should be_true
    end
  end

  context "the @node ivar" do
    before(:each) do
      EY.dna_json = {
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
      run_hook { @node.nil? }.should be_false
    end

    it "has indifferent access" do
      run_hook { @node[:instance_role]  }.should == 'solo'
      run_hook { @node['instance_role'] }.should == 'solo'
    end

    it "has deep indifferent access" do
      run_hook { @node['applications']['myapp']['type'] }.should == 'rails'
      run_hook { @node[:applications]['myapp'][:type]   }.should == 'rails'
      run_hook { @node[:applications][:myapp][:type]    }.should == 'rails'
    end
  end

  context "the @configuration ivar" do
    it "is available" do
      run_hook { @configuration.nil? }.should be_false
    end

    it "has the configuration in it" do
      run_hook('bert' => 'ernie') { @configuration.bert }.should == 'ernie'
    end

    it "can be accessed with method calls, with [:symbols], or ['strings']" do
      run_hook('bert' => 'ernie') { @configuration.bert }.should == 'ernie'
      run_hook('bert' => 'ernie') { @configuration[:bert] }.should == 'ernie'
      run_hook('bert' => 'ernie') { @configuration['bert'] }.should == 'ernie'
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
        run_hook { @configuration.has_key?(attribute) }.should be_true
      end
    end
  end

  context "has methods to run code only on certain instances" do
    def scenarios
      [
        {:instance_role => 'solo'},
        {:instance_role => 'app_master'},
        {:instance_role => 'app'},
        {:instance_role => 'db_master'},
        {:instance_role => 'db_slave'},
        {:instance_role => 'util', :name => "alpha"},
        {:instance_role => 'util', :name => "beta"},
        {:instance_role => 'util', :name => "gamma"},
      ]
    end

    def where_code_runs_with(method, *args)
      scenarios.map do |s|
        @callback_context.configuration[:current_role] = s[:instance_role]
        @callback_context.configuration[:current_name] = s[:name]

        if run_hook { send(method, *args) { 'ran!'} } == 'ran!'
          result = s[:instance_role]
          result << "_#{s[:name]}" if s[:name]
          result
        end
      end.compact
    end

    it "#on_app_master runs on app masters and solos" do
      where_code_runs_with(:on_app_master).should == %w(solo app_master)
    end

    it "#on_app_servers runs on app masters, app slaves, and solos" do
      where_code_runs_with(:on_app_servers).should == %w(solo app_master app)
    end

    it "#on_app_servers_and_utilities does what it says on the tin" do
      where_code_runs_with(:on_app_servers_and_utilities).should ==
        %w(solo app_master app util_alpha util_beta util_gamma)
    end

    it "#on_utilities() runs on all utility instances" do
      where_code_runs_with(:on_utilities).should ==
        %w(util_alpha util_beta util_gamma)
    end

    it "#on_utilities('sometype') runs on only utilities of type 'sometype'" do
      where_code_runs_with(:on_utilities, 'alpha').should == %w(util_alpha)
    end

    it "#on_utilities('type1', 'type2') runs on utilities of both types" do
      where_code_runs_with(:on_utilities, 'alpha', 'beta').should ==
        %w(util_alpha util_beta)
    end

    it "#on_utilities can be invoked with (['a', 'b']) or ('a', 'b')" do
      where_code_runs_with(:on_utilities, %w[alpha beta]).should ==
        where_code_runs_with(:on_utilities, 'alpha', 'beta')
    end

  end

  context "#syntax_error" do
    it "returns nil for hook files containing valid Ruby syntax" do
      hook_path = File.expand_path('../fixtures/valid_hook.rb', __FILE__)
      @hook.syntax_error(hook_path).should be_nil
    end

    it "returns a brief problem description for hook files containing valid Ruby syntax" do
      hook_path = File.expand_path('../fixtures/invalid_hook.rb', __FILE__)
      desc = "spec/fixtures/invalid_hook.rb:1: syntax error, unexpected '^'"
      match = /\A.*#{Regexp.escape desc}\Z/
      @hook.syntax_error(hook_path).should =~ match
    end
  end
end
