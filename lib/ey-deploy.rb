require 'escape'

$LOAD_PATH.push(File.expand_path("ey-deploy", File.dirname(__FILE__)))

require 'version'
require 'compatibility'
require 'strategies/git'
require 'task'
require 'server'
require 'deploy'
require 'deploy_hook'
require 'cli'
require 'configuration'

module EY
  def self.node
    @node ||= deep_indifferentize(JSON.parse(dna_json))
  end

  def self.dna_json
    @dna_json ||= `sudo cat /etc/chef/dna.json`
  end

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
