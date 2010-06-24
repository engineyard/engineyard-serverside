require File.dirname(__FILE__) + '/spec_helper'

describe "the bundler-upgrade script" do
  class TestBundlerInstaller < EY::BundlerInstaller
    attr_accessor :commands

    def initialize
      self.commands = []
    end

    def system(cmd)
      commands << cmd
      true
    end
  end

  def run_with_bundler_versions(versions)
    source_index_args = versions.inject({}) do |acc, this_version|
      spec = Gem::Specification.new do |s|
        s.name = 'bundler'
        s.authors = ["Bundler Guys"]
        s.date = Time.utc(2010, 1, 2)
        s.files = ['lib/bundler.rb'] # or something
        s.specification_version = 2
        s.version = Gem::Version.new(this_version)
      end
      acc.merge("bundler-#{this_version}" => spec)
    end

    Gem.should_receive(:source_index).and_return(Gem::SourceIndex.new(source_index_args))
    @harness.install('0.9.26')
  end

  before(:each) do
    @harness = TestBundlerInstaller.new
  end

  it "installs bundler if bundler is missing" do
    run_with_bundler_versions([])

    @harness.commands.size.should == 1
    @harness.commands.first.should =~ /gem install bundler/
  end

  it "installs the version if a different bundler is present" do
    # "gem update" won't work here since we don't necessarily want the
    # latest version
    run_with_bundler_versions(['0.9.20'])
    @harness.commands.size.should == 1
    @harness.commands.first.should =~ /gem install.*bundler.*0.9.26/
  end

  it "does nothing if the desired version is present" do
    run_with_bundler_versions(['0.9.20', '0.9.26'])
    @harness.commands.should be_empty
  end
end
