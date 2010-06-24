require File.dirname(__FILE__) + '/spec_helper'

describe "the bundler version retrieved from the lockfile" do
  def get_version(file)
    full_path = File.expand_path("../support/lockfiles/#{file}", __FILE__)
    EY::DeployBase.new({}).get_bundler_version(full_path)
  end

  it "returns the default version for an 0.9 lockfile without a bundler dependency" do
    get_version('0.9-no-bundler').should == EY::DeployBase::DEFAULT_09_BUNDLER
  end

  it "gets the version from an 0.9 lockfile with a bundler dependency" do
    get_version('0.9-with-bundler').should == '0.9.24'
  end

  it "returns the default version for a 1.0 lockfile without a bundler dependency" do
    get_version('1.0-no-bundler').should == EY::DeployBase::DEFAULT_10_BUNDLER
  end

  it "gets the version from a 1.0 lockfile with a bundler dependency" do
    get_version('1.0-with-bundler').should == '1.0.0.beta.1'
  end

  it "raises an error if it can't parse the file" do
    lambda { get_version('not-a-lockfile') }.should raise_error
  end
end
