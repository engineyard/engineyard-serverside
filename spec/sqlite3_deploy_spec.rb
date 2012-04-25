require 'spec_helper'

describe "Deploying an application with sqlite3 as the only DB adapter in the Gemfile.lock" do
  before(:all) do
    @release_path  = nil
    @shared_path   = nil
    @framework_env = nil

    deploy_test_application('sqlite3') do |deployer|
      @shared_path   = deployer.shared_path
      @release_path  = deployer.release_path
      @framework_env = deployer.framework_env
    end
  end

  it 'should symlink database.sqlite3.yml' do
    @release_path.join('config', 'database.yml').should exist
  end

  it 'should create database.sqlite3.yml in a shared location' do
    @shared_path.join('config', 'database.sqlite3.yml').should exist
  end

  it 'should put a reference to a shared database in database.sqlite3.yml' do
    contents = @release_path.join('config', 'database.yml').read
    contents.should include(@shared_path.join('databases', "#{@framework_env}.sqlite3").expand_path)
  end

  it 'should create the shared database' do
    @shared_path.join('databases', "#{@framework_env}.sqlite3").should exist
  end

end
