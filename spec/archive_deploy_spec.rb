require 'spec_helper'

class EY::Serverside::Strategy::Archive
  def fetch_command
    "cp #{uri} ./"
  end
end

describe "Deploying a simple application" do
  let(:adapter) {
    EY::Serverside::Adapter.new do |args|
      args.account_name = "account"
      args.app = "application_name"
      args.stack = "nginx_unicorn"
      args.environment_name = "environment_name"
      args.framework_env = "production"
      args.archive = FIXTURES_DIR.join('retwisj.war')
      args.verbose = true
      args.instances = [{ :hostname => "localhost", :roles => ["solo"], :name => "single" }]
      args.config = {
        "deploy_to" => deploy_dir,
        "release_path"     => release_path.to_s,
        "group"            => GROUP
      }
    end
  }

  let(:binpath) {
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'engineyard-serverside'))
  }

  before(:all) do
    argv = adapter.deploy.commands.last.to_argv[2..-1]
    with_mocked_commands do
      capture do
        EY::Serverside::CLI.start(argv)
      end
    end
  end

  it "exploded the war" do
    %w(META-INF WEB-INF).each {|dir|
      File.exists?(deploy_dir.join('current', dir))
    }
  end

  it "creates a REVISION file" do
    path = deploy_dir.join('current', 'REVISION')
    expect(path).to exist
    expect(File.read(path).strip).to eq("retwisj.war")
  end

  it "restarts the app servers" do
    restart = deploy_dir.join('current', 'restart')
    restart.should exist
    expect(restart.read.chomp).to eq(%|LANG="en_US.UTF-8" /engineyard/bin/app_application_name deploy|)
  end
end
