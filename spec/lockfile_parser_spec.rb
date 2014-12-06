require 'spec_helper'

describe "the bundler version retrieved from the lockfile" do
  def load_lockfile(file)
    File.read(File.expand_path("../fixtures/lockfiles/#{file}", __FILE__))
  end

  def get_parser(file)
    EY::Serverside::DependencyManager::Bundler::Lockfile.new(load_lockfile(file))
  end

  def get_version(file)
    get_parser(file).bundler_version
  end

  it "raises an error with pre 0.9 bundler lockfiles" do
    expect { get_version('0.9-no-bundler')   }.to raise_error(RuntimeError, /Malformed or pre bundler-1.0.0 Gemfile.lock/)
    expect { get_version('0.9-with-bundler') }.to raise_error(RuntimeError, /Malformed or pre bundler-1.0.0 Gemfile.lock/)
  end

  it "has a default version" do
    expect(EY::Serverside::DependencyManager::Bundler.default_version).not_to be_nil
    expect(EY::Serverside::DependencyManager::Bundler::DEFAULT_VERSION).not_to be_nil
  end

  it "returns the default version for a 1.0 lockfile without a bundler dependency" do
    expect(get_version('1.0-no-bundler')).to eq(EY::Serverside::DependencyManager::Bundler.default_version)
  end

  it "gets the version from a 1.0.0.rc.1 lockfile w/dependency on 1.0.0.rc.1" do
    expect(get_version('1.0.0.rc.1-with-bundler')).to eq('1.0.0.rc.1')
  end

  it "gets the version from a 1.0.6 lockfile w/dependency on 1.0.6" do
    expect(get_version('1.0.6-with-bundler')).to eq('1.0.6')
  end

  it "gets the version from a 1.0.6 lockfile w/dependency on 1.0.6 (bundled ~> 1.0.0)" do
    expect(get_version('1.0.6-with-any-bundler')).to eq('1.0.6')
  end

  it "gets the version from a 1.0.6 lockfile w/o dependency" do
    expect(get_version('1.0.6-no-bundler')).to eq('1.0.6')
  end

  it "raises an error if it can't parse the file" do
    expect { get_version('not-a-lockfile') }.to raise_error(RuntimeError, /Malformed or pre bundler-1.0.0 Gemfile.lock/)
  end

  context "rails version" do
    it "retrieves rails version" do
      expect(get_parser('1.3.1-rails-3.2.13').rails_version).to eq("3.2.13")
    end

    it "finds no rails version" do
      expect(get_parser('1.0.18-mysql2').rails_version).to eq(nil)
    end
  end

  context "checking for gems in the dependencies" do
    it "does not have any database adapters in a gemfile lock without them" do
      expect(get_parser('1.0.6-no-bundler').any_database_adapter?).to be_falsey
    end

    it "has a database adapter in a Gemfile.lock with do_mysql" do
      expect(get_parser('1.0.18-do_mysql').any_database_adapter?).to be_truthy
    end

    it "has a database adapter in a Gemfile.lock with mysql" do
      expect(get_parser('1.0.18-mysql').any_database_adapter?).to be_truthy
    end

    it "has a database adapter in a Gemfile.lock with mysql2" do
      expect(get_parser('1.0.18-mysql2').any_database_adapter?).to be_truthy
    end

    it "has a database adapter in a Gemfile.lock with pg" do
      expect(get_parser('1.0.18-pg').any_database_adapter?).to be_truthy
    end

    it "has a database adapter in a Gemfile.lock with do_postgres" do
      expect(get_parser('1.0.18-do_postgres').any_database_adapter?).to be_truthy
    end
  end

  context "fetching the right version number" do
    subject { get_parser('1.0.6-no-bundler') }

    it "uses the default version when there is no bundler version" do
      expect(subject.fetch_version(nil, nil)).to eq(EY::Serverside::DependencyManager::Bundler.default_version)
    end

    it "uses the given version when there is no operator" do
      expect(subject.fetch_version(nil, '1.0.1')).to eq('1.0.1')
    end

    it "uses the given version when the qualifier is `='" do
      expect(subject.fetch_version('=', '1.0.1')).to eq('1.0.1')
    end

    it "uses the default version when we get a pessimistic qualifier and is lower than the default version" do
      expect(subject.fetch_version('~>', '1.3.1')).to eq(EY::Serverside::DependencyManager::Bundler.default_version)
    end

    it "uses the given version when we get a pessimistic qualifier that doesn't match the default version" do
      expect(subject.fetch_version('~>', '1.0.0')).to eq('1.0.0')
    end

    it "uses the given version when it's geater of equal than the default version" do
      expect(subject.fetch_version('>=', '1.100.0')).to eq('1.100.0')
    end

    it "uses the default version when the given version is lower" do
      expect(subject.fetch_version('>=', '1.0.1')).to eq(EY::Serverside::DependencyManager::Bundler.default_version)
    end

    it "selects only the first version expression" do
      scan = subject.scan_gem('bundler', 'bundler (>=1.0.1, <2.0.0)')
      expect(scan.last).to eq('1.0.1')
    end
  end
end
