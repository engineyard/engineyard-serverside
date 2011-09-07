$LOAD_PATH.push File.expand_path("../lib", File.dirname(__FILE__))

# Bundler.require :default, :test - FIXME when we return to ruby 1.8.7+
require 'rubygems'
require 'spec'
require 'pp'
require 'tmpdir'
require 'engineyard-serverside'

module EY
  module Serverside
    def self.dna_json=(j)
      @dna_json = j;
      @node = nil
      j
    end

    module LoggedOutput
      def info(_) end

      def logged_system(cmd)
        system("#{cmd} 2>/dev/null")
      end
    end

    class Strategies::Git
      def short_log_message(_) "" end
    end
  end
end

FIXTURES_DIR = File.expand_path("../fixtures", __FILE__)
GITREPO_DIR = "#{FIXTURES_DIR}/gitrepo"

FileUtils.rm_rf GITREPO_DIR if File.exists? GITREPO_DIR
Kernel.system "tar xzf #{GITREPO_DIR}.tar.gz -C #{FIXTURES_DIR}"

def setup_dna_json(options = {})
  EY::Serverside.dna_json = {
    'environment' => {
      "framework_env" => "production",
    },
    'engineyard' => {
      "environment" => {
        "apps" => [{
          "name"          => "myfirstapp",
          "database_name" => "myfirstapp",
          "type"          => "rack"
        }],
        "instances"     => dna_instances_for(options[:cluster_type] || :solo),
        "components"    => [{"key" => "ruby_187"}],
        "framework_env" => "production",
        "stack_name"    => "nginx_passenger",
        "ssh_username"  => "deploy",
        "ssh_password"  => "12345678",
        "db_stack_name" => options[:db_stack_name] || "mysql",
        "db_host"       => "localhost"
      }
    }    
  }.to_json
end
def dna_instances_for(cluster_type = :solo)
  case cluster_type
  when :solo
    [{
      "public_hostname" => "solo.compute-1.amazonaws.com",
      "role" => "solo",
      "private_hostname" => "solo.compute-1.internal"
    }]
  when :slaves
    [
      {
        "public_hostname" => "app_master.compute-1.amazonaws.com",
        "role" => "app_master",
        "private_hostname" => "app_master.ec2.internal"
      },
      {
        "public_hostname" => "db_master.compute-1.amazonaws.com",
        "role" => "db_master",
        "private_hostname" => "db_master.ec2.internal"
      },
      {
        "public_hostname" => "db_slave1.compute-1.amazonaws.com",
        "role" => "db_slave",
        "private_hostname" => "db_slave1.ec2.internal",
      },
      {
        "public_hostname" => "db_slave2.compute-1.amazonaws.com",
        "role" => "db_slave",
        "private_hostname" => "db_slave2.ec2.internal",
      }
    ]
  end
end

Spec::Runner.configure do |config|
  config.before(:all) do
    EY::Serverside.dna_json = {}.to_json
  end
end
