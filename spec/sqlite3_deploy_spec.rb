require 'spec_helper'

describe "Deploying an application with sqlite3 as the only DB adapter in the Gemfile.lock" do
  before(:all) do
    @release_path  = nil
    @shared_path   = nil
    @framework_env = nil

    deploy_test_application do |deployer|
      gemfile                    = File.expand_path('../fixtures/gemfiles/1.0.21-rails-31-with-sqlite', __FILE__)
      lockfile                   = File.expand_path('../fixtures/lockfiles/1.0.21-rails-31-with-sqlite', __FILE__)
      deployer.gemfile_contents  = File.read(gemfile)
      deployer.lockfile_contents = File.read(lockfile)

      @shared_path               = deployer.shared_path
      @release_path              = deployer.release_path
      @framework_env             = deployer.framework_env
    end
  end

  it 'should symlink database.sqlite3.yml' do
    File.exist?(File.join(@release_path, 'config', 'database.yml')).should be_true
  end

  it 'should create database.sqlite3.yml in a shared location' do
    File.exist?(File.join(@shared_path, 'config', 'database.sqlite3.yml')).should be_true
  end

  it 'should put a reference to a shared database in database.sqlite3.yml' do
    contents = File.read(File.join(@release_path, 'config', 'database.yml'))
    contents.should include(File.expand_path(File.join(@shared_path, 'databases', "#{@framework_env}.sqlite3")))
  end

  it 'should create the shared database' do
    File.exist?(File.join(@shared_path, 'databases', "#{@framework_env}.sqlite3")).should be_true
  end

end
