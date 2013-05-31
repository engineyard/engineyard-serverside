require 'spec_helper'

describe "Deploying an application with sqlite3 as the only DB adapter in the Gemfile.lock" do
  before(:all) do
    @release_path  = nil
    @shared_path   = nil
    @framework_env = nil

    deploy_test_application('sqlite3')
    @shared_path   = @deployer.config.paths.shared
    @release_path  = @deployer.config.paths.active_release
    @framework_env = @deployer.framework_env
  end

  it 'should symlink database.sqlite3.yml' do
    @release_path.join('config', 'database.yml').should exist
  end

  it 'should create database.sqlite3.yml in a shared location' do
    @shared_path.join('config', 'database.sqlite3.yml').should exist
  end

  it 'should put a reference to a shared database in database.sqlite3.yml' do
    contents = @release_path.join('config', 'database.yml').read
    contents.should include(@shared_path.join('databases', "#{@framework_env}.sqlite3").expand_path.to_s)
  end

  it 'should create the shared database' do
    @shared_path.join('databases', "#{@framework_env}.sqlite3").should exist
  end

  it 'should contain valid yaml config' do
    config = YAML.load_file(@release_path.join('config', 'database.yml'))
    config[@framework_env]['adapter'].should == 'sqlite3'
    config[@framework_env]['database'].should == @shared_path.join('databases', "#{@framework_env}.sqlite3").expand_path.to_s
  end

end
