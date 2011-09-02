$LOAD_PATH.unshift File.expand_path('vendor/thor/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/open4/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/escape/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/json_pure/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/dataflow', File.dirname(__FILE__))

require 'escape'
require 'json'
require 'dataflow'

require 'engineyard-serverside/version'
require 'engineyard-serverside/strategies/git'
require 'engineyard-serverside/task'
require 'engineyard-serverside/server'
require 'engineyard-serverside/deploy'
require 'engineyard-serverside/deploy_hook'
require 'engineyard-serverside/lockfile_parser'
require 'engineyard-serverside/bundle_installer'
require 'engineyard-serverside/cli'
require 'engineyard-serverside/configuration'
require 'engineyard-serverside/deprecation'
require 'engineyard-serverside/env_vars_hook'

module EY
  module Serverside
    
    def self.node
      @node ||= deep_indifferentize(JSON.parse(dna_json))
    end

    def self.dna_json
      @dna_json ||= if File.exist?('/etc/chef/dna.json')
                      `sudo cat /etc/chef/dna.json`
                    else
                      {}.to_json
                    end
    end

    RemoteFailure = Class.new StandardError

    private
    def self.deep_indifferentize(thing)
      if thing.kind_of?(Hash)
        indifferent_hash = Thor::CoreExt::HashWithIndifferentAccess.new
        thing.each do |k, v|
          indifferent_hash[k] = deep_indifferentize(v)
        end
        indifferent_hash
      elsif thing.kind_of?(Array)
        thing.map {|x| deep_indifferentize(x)}
      else
        thing
      end
    end
    
  end
end
