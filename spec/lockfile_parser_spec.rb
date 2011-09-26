require 'spec_helper'

describe "the bundler version retrieved from the lockfile" do
  def load_lockfile(file)
    File.read(File.expand_path("../support/lockfiles/#{file}", __FILE__))
  end

  def get_parser(file)
    EY::Serverside::LockfileParser.new(load_lockfile(file))
  end

  def get_version(file)
    get_parser(file).bundler_version
  end

  it "raises an error with pre 0.9 bundler lockfiles" do
    lambda { get_version('0.9-no-bundler')   }.should raise_error(RuntimeError, /Malformed or pre bundler-1.0.0 Gemfile.lock/)
    lambda { get_version('0.9-with-bundler') }.should raise_error(RuntimeError, /Malformed or pre bundler-1.0.0 Gemfile.lock/)
  end

  it "returns the default version for a 1.0 lockfile without a bundler dependency" do
    get_version('1.0-no-bundler').should == EY::Serverside::LockfileParser::DEFAULT
  end

  it "gets the version from a 1.0.0.rc.1 lockfile w/dependency on 1.0.0.rc.1" do
    get_version('1.0.0.rc.1-with-bundler').should == '1.0.0.rc.1'
  end

  it "gets the version from a 1.0.6 lockfile w/dependency on 1.0.6" do
    get_version('1.0.6-with-bundler').should == '1.0.6'
  end

  it "gets the version from a 1.0.6 lockfile w/dependency on 1.0.6 (bundled ~> 1.0.0)" do
    get_version('1.0.6-with-any-bundler').should == '1.0.6'
  end

  it "gets the version from a 1.0.6 lockfile w/o dependency" do
    get_version('1.0.6-no-bundler').should == '1.0.6'
  end

  it "raises an error if it can't parse the file" do
    lambda { get_version('not-a-lockfile') }.should raise_error(RuntimeError, /Malformed or pre bundler-1.0.0 Gemfile.lock/)
  end

  context "checking for gems in the dependencies" do
    it "does not have any database adapters in a gemfile lock without them" do
      get_parser('1.0.6-no-bundler').any_database_adapter?.should be_false
    end

    it "has a database adapter in a Gemfile.lock with do_mysql" do
      get_parser('1.0.18-do_mysql').any_database_adapter?.should be_true
    end

    it "has a database adapter in a Gemfile.lock with mysql" do
      get_parser('1.0.18-mysql').any_database_adapter?.should be_true
    end

    it "has a database adapter in a Gemfile.lock with mysql2" do
      get_parser('1.0.18-mysql2').any_database_adapter?.should be_true
    end

    it "has a database adapter in a Gemfile.lock with pg" do
      get_parser('1.0.18-pg').any_database_adapter?.should be_true
    end

    it "has a database adapter in a Gemfile.lock with do_postgres" do
      get_parser('1.0.18-do_postgres').any_database_adapter?.should be_true
    end
  end

  context "fetching the right version number" do
    subject { get_parser('1.0.6-no-bundler') }

    it "uses the default version when there is no bundler version" do
      subject.fetch_version(nil, nil).should == EY::Serverside::LockfileParser::DEFAULT
    end

    it "uses the given version when the qualifier is `='" do
      subject.fetch_version('1.0.1', '=').should == '1.0.1'
    end

    it "uses the default version when we get a pessimistic qualifier and is lower than the default version" do
      subject.fetch_version('1.0.1', '~>').should == '1.0.10'
    end

    it "uses the given version when we get a pessimistic qualifier that doesn't match the default version" do
      subject.fetch_version('1.1.0', '~>').should == '1.1.0'
    end

    it "uses the given version when it's geater of equal than the default version" do
      subject.fetch_version('1.1.0', '>=').should == '1.1.0'
    end

    it "uses the default version when the given version is lower" do
      subject.fetch_version('1.0.1', '>=').should == EY::Serverside::LockfileParser::DEFAULT
    end

    it "selects only the first version expression" do
      scan = subject.scan_bundler 'bundler (>=1.0.1, <2.0.0)'
      scan.last.should == '1.0.1'
    end
  end
end
