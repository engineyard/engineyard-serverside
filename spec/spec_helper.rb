$LOAD_PATH.push File.expand_path("../lib", File.dirname(__FILE__))

if defined?(Bundler)
  Bundler.require :default, :test
else
  require 'rubygems'
end

require 'pp'
require 'engineyard-serverside'
require File.expand_path('../support/integration', __FILE__)

module EY
  module Serverside
    def self.dna_json=(j)
      @dna_json = j
      @node = nil
    end

    module LoggedOutput
      def info(_) end

      def logged_system(cmd)
        output = `#{cmd} 2>&1`
        successful = ($? == 0)
        if ENV['VERBOSE']
          if successful
            $stdout.puts "#{cmd}\n#{output.strip}".chomp
          else
            $stderr.puts "\nCommand `#{cmd}` exited with status #{$?.exitstatus}: '#{output.strip}'"
          end
        end
        successful
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

Spec::Runner.configure do |config|
  `which npm 2>&1`
  $NPM_INSTALLED = ($? == 0)
  unless $NPM_INSTALLED
    $stderr.puts "npm not found; skipping Node.js specs."
  end

  config.before(:all) do
    $DISABLE_GEMFILE = false
    $DISABLE_LOCKFILE = false
    EY::Serverside.dna_json = {}.to_json
  end
end
