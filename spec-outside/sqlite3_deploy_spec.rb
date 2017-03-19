require 'spec_helper'

describe "Deploying an application with sqlite3 as the only DB adapter in the Gemfile.lock" do
  before(:all) do
    @release_path  = nil
    @shared_path   = nil
    @framework_env = nil

    deploy_test_application('sqlite3')
    @shared_path   = @deployer.config.paths.shared
    @release_path  = @deployer.config.paths.active_release
    @framework_env = @deployer.config.framework_env
  end

  it 'should symlink database.sqlite3.yml' do
    expect(@release_path.join('config', 'database.yml')).to exist
  end

  it 'should create database.sqlite3.yml in a shared location' do
    expect(@shared_path.join('config', 'database.sqlite3.yml')).to exist
  end

  it 'should put a reference to a shared database in database.sqlite3.yml' do
    contents = @release_path.join('config', 'database.yml').read
    expect(contents).to include(@shared_path.join('databases', "#{@framework_env}.sqlite3").expand_path.to_s)
  end

  it 'should create the shared database' do
    expect(@shared_path.join('databases', "#{@framework_env}.sqlite3")).to exist
  end

  it 'should contain valid yaml config' do
    config = YAML.load_file(@release_path.join('config', 'database.yml'))
    expect(config[@framework_env]['adapter']).to eq('sqlite3')
    expect(config[@framework_env]['database']).to eq(@shared_path.join('databases', "#{@framework_env}.sqlite3").expand_path.to_s)
  end

end
