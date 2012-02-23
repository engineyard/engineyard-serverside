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

  it "deprecates EY::Serverside::LoggedOutput for EY::Serverside::Shell::Helpers" do
    EY::Serverside::LoggedOutput.should == EY::Serverside::Shell::Helpers
    @warnings.string.should include("EY::Serverside::LoggedOutput")
  end

  it "doesn't interfere with unrelated constants" do
    lambda{ EY::Serverside::WTFNotDefined }.should raise_error(NameError, /uninitialized constant.*WTFNotDefined/)
  end
end
