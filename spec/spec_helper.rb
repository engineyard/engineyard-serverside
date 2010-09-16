$LOAD_PATH.push File.expand_path("../lib", File.dirname(__FILE__))
$LOAD_PATH.push File.expand_path("support", File.dirname(__FILE__))

Bundler.require :default, :test
require 'pp'
require 'engineyard-serverside'

require 'full_test_deploy'
require 'full_deploy_helpers'

class EY::Metadata::DnaJsonProvider
  def self.dna_json=(j)
    @dna_json = j
    @raw = nil
    j
  end
end

module EY
  def self.dna_json=(j)
    EY::Metadata::DnaJsonProvider.dna_json = j
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

FIXTURES_DIR = File.expand_path("../fixtures", __FILE__)
GITREPO_DIR = "#{FIXTURES_DIR}/gitrepo"

FileUtils.rm_rf GITREPO_DIR if File.exists? GITREPO_DIR
Kernel.system "tar xzf #{GITREPO_DIR}.tar.gz -C #{FIXTURES_DIR}"

Spec::Runner.configure do |config|
  config.before(:all) do
    EY.dna_json = {}.to_json
  end
end
