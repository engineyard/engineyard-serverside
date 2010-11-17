require File.dirname(__FILE__) + '/spec_helper'

describe "the bundler version retrieved from the lockfile" do
  def get_version(file)
    full_path = File.expand_path("../support/lockfiles/#{file}", __FILE__)
    @config = EY::Deploy::Configuration.new('deploy_to' => 'dontcare')
    EY::DeployBase.new(@config).get_bundler_installer(full_path).version
  end

  it "returns the default version for an 0.9 lockfile without a bundler dependency" do
    get_version('0.9-no-bundler').should == EY::DeployBase.new(@config).send(:default_09_bundler)
  end

  it "gets the version from an 0.9 lockfile with a bundler dependency" do
    get_version('0.9-with-bundler').should == '0.9.24'
  end

  it "returns the default version for a 1.0 lockfile without a bundler dependency" do
    get_version('1.0-no-bundler').should == EY::DeployBase.new(@config).send(:default_10_bundler)
  end

  it "gets the version from a 1.0.0.rc.1 lockfile w/dependency on 1.0.0.rc.1" do
    # This is a real, customer-generated lockfile
    get_version('1.0.0.rc.1-with-bundler').should == '1.0.0.rc.1'
  end

  it "gets the version from a 1.0.6 lockfile w/dependency on 1.0.6" do
    # This is a real, customer-generated lockfile
    get_version('1.0.6-with-bundler').should == '1.0.6'
  end

  it "gets the version from a 1.0.6 lockfile w/dependency on 1.0.6 (bundled ~> 1.0.0)" do
    # This is a real, customer-generated lockfile
    get_version('1.0.6-with-any-bundler').should == '1.0.6'
  end

  it "gets the version from a 1.0.6 lockfile w/o dependency" do
    # This is a real, customer-generated lockfile
    get_version('1.0.6-no-bundler').should == '1.0.6'
  end

  it "raises an error if it can't parse the file" do
    lambda { get_version('not-a-lockfile') }.should raise_error(RuntimeError, /Unknown lockfile format/)
  end

  it "raises an error if it can't parse evil yaml" do
    lambda { get_version('evil-yaml') }.should raise_error(RuntimeError, /Unknown lockfile format/)
  end

end
