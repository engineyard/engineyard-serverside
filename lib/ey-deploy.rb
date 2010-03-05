$LOAD_PATH.push(File.expand_path("ey-deploy", File.dirname(__FILE__)))

require 'version'
require 'compatibility'
require 'strategies/git'
require 'task'
require 'server'
require 'deploy'
require 'cli'
require 'configuration'

module EY
  def self.node
    @node ||= JSON.parse(File.read("/etc/chef/dna.json"))
  end
end