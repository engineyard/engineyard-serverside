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
    expect(EY::Serverside::LoggedOutput).to eq(EY::Serverside::Shell::Helpers)
    expect(@warnings.string).to include("EY::Serverside::LoggedOutput")
  end

  it "doesn't interfere with unrelated constants" do
    expect{ EY::Serverside::WTFNotDefined }.to raise_error(NameError, /uninitialized constant.*WTFNotDefined/)
  end
end
