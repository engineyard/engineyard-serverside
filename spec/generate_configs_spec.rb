require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/lib/full_test_deploy'

module EY::Serverside::Strategies::GenerateDatabaseYmlIntegrationSpec
  module Helpers
    attr_accessor :db_gemfile_folder
    attr_accessor :db_keepfile

    def update_repository_cache
      cached_copy = File.join(c.shared_path, 'cached-copy')
      FileUtils.mkdir_p(cached_copy)
      FileUtils.mkdir_p(shared_config = File.join(c.shared_path, 'config'))

      # set engineyard.apps[0].type? default: rack
      # set engineyard.environment.components[0].key? default: ruby_187
      # copy over Gemfile & Gemfile.lock from fixtures/gemfiles/<db_gemfile_folder>
      gemfile_fixtures_dir = File.expand_path("../fixtures/gemfiles/#{db_gemfile_folder}", __FILE__)

      Dir.chdir(cached_copy) do
        Dir[gemfile_fixtures_dir + "/*"].each {|f| FileUtils.cp_r(f, File.basename(f))}
        FileUtils.mkdir_p('config')
        Dir.chdir('config') do
          Dir[gemfile_fixtures_dir + "/config/*"].each {|f| FileUtils.cp_r(f, File.basename(f))}

          `touch keep.database.yml` if db_keepfile
        end
      end

      # FileUtils.cp_r(gemfile_fixtures_dir + "/", cached_copy) FIXME - why do you work?
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
    end
  end
end

describe "generate database.yml for a solo" do
  def deploy_with_gemfile(db_gemfile_folder, db_type, cluster_type = :solo, config_overrides = {})
    @deploy_dir = File.join(Dir.tmpdir, "serverside-deploy-#{Time.now.to_i}-#{$$}")

    # set up EY::Serverside::Server like we're on a solo
    EY::Serverside::Server.reset
    EY::Serverside::Server.add(:hostname => 'localhost', :roles => %w[solo])

    setup_dna_json(:cluster_type => cluster_type, :db_stack_name => db_type)

    # run a deploy
    config = EY::Serverside::Deploy::Configuration.new(config_overrides.merge({
        "strategy"      => "GenerateDatabaseYmlIntegrationSpec",
        "deploy_to"     => @deploy_dir,
        "group"         => `id -gn`.strip,
        "stack"         => 'nginx_passenger',
        "migrate"       => "ruby -e 'puts ENV[\"PATH\"]' > #{@deploy_dir}/path-when-migrating",
        'app'           => 'myfirstapp',
        'framework_env' => 'production'
      }))

    FileUtils.mkdir_p(File.join(@deploy_dir, 'shared'))
    Dir.chdir(File.join(@deploy_dir, 'shared')) do
      # pretend there is a shared bundled_gems directory
      FileUtils.mkdir_p('bundled_gems')

      %w(RUBY_VERSION SYSTEM_VERSION).each do |name|
        File.open(File.join('bundled_gems', name), "w") { |f| f.write("old\n") }
      end

      FileUtils.mkdir_p('config')
      `touch config/keep.database.yml` if config_overrides[:keepfile_base] == 'shared'
    end

    @binpath = $0 = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
    @deployer = FullTestDeploy.new(config)
    @deployer.db_gemfile_folder = db_gemfile_folder
    @deployer.db_keepfile = config_overrides[:keepfile_base] == 'shared/cached-copy'
    @deployer.deploy
  end

  [
    [ 'activerecord_sqlite3',        'mysql',      'mysql'],
    [ 'activerecord_sqlite3',        'postgresql', 'postgresql'],
    [ 'activerecord_mysql',          'mysql',      'mysql'],
    [ 'activerecord_mysql2',         'mysql',      'mysql2'],
    [ 'activerecord_pg',             'postgresql', 'postgresql'],
    [ 'activerecord_jdbcmysql',      'mysql',      'mysql'],     # jruby
    [ 'activerecord_jdbcpostgresql', 'postgresql', 'postgresql'] # jruby
  ].each do | db_gemfile_folder,     db_type,      expected_adapter |
    it "from Gemfile tagged '#{db_gemfile_folder}' generates a database.yml with adapter #{expected_adapter}" do
      deploy_with_gemfile(db_gemfile_folder, db_type)

      database_yml_file = File.join(@deploy_dir, 'current', 'config', 'database.yml')
      File.exist?(database_yml_file).should be_true
      database_yml = File.read(database_yml_file)

      # Expected database.yml to look like:
      expected = <<-EOS.gsub(/^\s{6}/, '')
      production:
        adapter:   #{expected_adapter}
        database:  myfirstapp
        username:  deploy
        password:  12345678
        host:      solo.compute-1.amazonaws.com
        reconnect: true
      EOS
      expected.should == database_yml
    end
  end

  it "overrides the adapter from (ey.yml derived) configuration" do
    deploy_with_gemfile('activerecord_mysql2', 'mysql', :solo, :db_adapter => 'foobar')

    expected = <<-EOS.gsub(/^\s{4}/, '')
    production:
      adapter:   foobar
      database:  myfirstapp
      username:  deploy
      password:  12345678
      host:      solo.compute-1.amazonaws.com
      reconnect: true
    EOS
    File.read(File.join(@deploy_dir, 'current', 'config', 'database.yml')).should == expected
  end

  it "separate db_master instance and slave instances" do
    deploy_with_gemfile('activerecord_mysql2', 'mysql', :slaves)

    expected = <<-EOS.gsub(/^\s{4}/, '')
    production:
      adapter:   mysql2
      database:  myfirstapp
      username:  deploy
      password:  12345678
      host:      db_master.compute-1.amazonaws.com
      reconnect: true
    slave:
      adapter:   mysql2
      database:  myfirstapp
      username:  deploy
      password:  12345678
      host:      db_slave1.compute-1.amazonaws.com
      reconnect: true
    slave_1:
      adapter:   mysql2
      database:  myfirstapp
      username:  deploy
      password:  12345678
      host:      db_slave2.compute-1.amazonaws.com
      reconnect: true
    EOS
    File.read(File.join(@deploy_dir, 'current', 'config', 'database.yml')).should == expected
  end

  it "generates a database.yml even if file already exists" do
    deploy_with_gemfile('diy_database_yml', 'mysql', :solo)

    expected = <<-EOS.gsub(/^\s{4}/, '')
    production:
      adapter:   mysql2
      database:  myfirstapp
      username:  deploy
      password:  12345678
      host:      solo.compute-1.amazonaws.com
      reconnect: true
    EOS
    File.read(File.join(@deploy_dir, 'current', 'config', 'database.yml')).should == expected
  end

  def spec_not_override_shared_db_file(base)
    deploy_with_gemfile('diy_database_yml', 'mysql', :solo, :keepfile_base => base)

    expected = <<-EOS.gsub(/^\s{6}/, '')
    production:
      adapter:   foobarbaz
      database:  myfirstapp
      username:  deploy
      password:  12345678
      host:      localhost
      reconnect: true
    EOS
    File.read(File.join(@deploy_dir, 'current', 'config', 'database.yml')).should == expected
  end

  it "do not override the database.yml if a keepfile exists at shared/config/database.yml" do
    spec_not_override_shared_db_file('shared')
  end

  it "do not override the database.yml if a keepfile exists at shared/cached-copy/config/database.yml" do
    spec_not_override_shared_db_file('shared/cached-copy')
  end
end

# framework type: rails vs sinatra vs node vs php
# rails 2 adapters: mysql/oracle/postgresql/sqlite2/sqlite3/frontbase/ibm_db
# rails 3 adapters: mysql/oracle/postgresql/sqlite3/frontbase/ibm_db/jdbcmysql/jdbcsqlite3/jdbcpostgresql/jdbc
# permutations to test:
# - rails/sinatra version? - hopefully not - just gems installed
# - ruby version / ruby type (mri vs jruby, mri 1.8.6 vs mri 1.9.2)?
# - Gemfile vs System gems? (look in Gemfile vs "gem list <name>")
# - gems installed - mysql, mysql2, pg, datamapper, activerecord, sqlite3?

# $ bundle -v
# Bundler version 1.0.18
# $ bundle list
# Gems included by the bundle:
#   * activemodel (3.0.10)
#   * activerecord (3.0.10)
#   * activesupport (3.0.10)
#   * arel (2.0.10)
#   * builder (2.1.2)
#   * bundler (1.0.18)
#   * i18n (0.5.0)
#   * mysql (2.8.1)
#   * tzinfo (0.3.29)
#
