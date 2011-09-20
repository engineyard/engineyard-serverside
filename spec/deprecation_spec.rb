require 'spec_helper'
require 'stringio'

describe EY::Serverside do
  before do
    @original_stderr = $stderr
    @warnings = StringIO.new
    $stderr = @warnings
  end

  after do
    $stderr = @original_stderr
  end

  def check_deprecation(new_const, prints_warning = true)
    old_name = new_const.to_s.gsub('EY::Serverside::', 'EY::')
    eval(old_name).should == new_const
    @warnings.string.should include(old_name) if prints_warning
  end

  it "preserves the old constants" do
    names = %w[BundleInstaller CLI Deploy DeployBase Deploy::Configuration
               DeployHook LockfileParser LoggedOutput Server Task
               Strategies Strategies::Git]

    names.map do |name|
      const = eval("::EY::Serverside::#{name}")
      # The way deprecations are implemented currently, we don't print
      # warning messages for constants that aren't directly under EY::
      prints_warning = name.include?('::') ? false : true
      check_deprecation(const, prints_warning)
    end
  end

  it "deprecates EY.dna_json and EY.node" do
    EY.dna_json.should == EY::Serverside.dna_json
    @warnings.string.should include("EY.dna_json")
    EY.node.should == EY::Serverside.node
    @warnings.string.should include("EY.node")
  end

  it "doesn't interfere with unrelated constants" do
    lambda{ EY::WTFNotDefined }.should raise_error(NameError, /uninitialized constant EY::WTFNotDefined/)
  end
end
