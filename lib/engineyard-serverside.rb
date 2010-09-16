$LOAD_PATH.push(File.expand_path("engineyard-serverside", File.dirname(__FILE__)))
$LOAD_PATH.unshift File.expand_path('vendor/thor/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/open4/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/escape/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/json_pure/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/dataflow', File.dirname(__FILE__))

require 'escape'
require 'json'
require 'dataflow'

require 'version'
require 'metadata'
require 'strategies/git'
require 'task'
require 'server'
require 'deploy'
require 'deploy_hook'
require 'deploy_delegate'
require 'lockfile_parser'
require 'bundle_installer'
require 'cli'
require 'configuration'

module EY
  RemoteFailure = Class.new StandardError
end
