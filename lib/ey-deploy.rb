$LOAD_PATH.push(File.expand_path("ey-deploy/server", File.dirname(__FILE__)))

require 'deploy'
require 'update'
require 'cli'

module EY
  DNA_FILE = "/etc/chef/dna.json"
end