require File.dirname(__FILE__) + '/spec_helper'

describe "deploy hook's context" do
  before(:each) do
    @hook_runner = EY::DeployHook.new(options)
    @callback_context = EY::DeployHook::CallbackContext.new(@hook_runner, @hook_runner.config)
  end

  def run_hook(options={}, &blk)
    raise ArgumentError unless block_given?
    options.each do |k, v|
      @hook_runner.config.configuration[k] = v    # ugh
    end

    # The hooks on the filesystem are run by passing a string to
    # context.instance_eval, not a block. However, using a block
    # should allow us to get the same degree of test coverage and
    # still let us have things like syntax checking work on this spec
    # file.
    @callback_context.instance_eval(&blk)
  end

  context "the #run method" do
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

  context "the #sudo method" do
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
end
