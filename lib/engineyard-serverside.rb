# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('vendor/escape/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/json_pure/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/open4/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path('vendor/thor/lib', File.dirname(__FILE__))

require 'escape'
require 'json'
require 'tmpdir'
require 'thor'
require 'open4'

require 'engineyard-serverside/version'
require 'engineyard-serverside/strategies/git'
require 'engineyard-serverside/task'
require 'engineyard-serverside/server'
require 'engineyard-serverside/deploy'
require 'engineyard-serverside/deploy_hook'
require 'engineyard-serverside/lockfile_parser'
require 'engineyard-serverside/cli'
require 'engineyard-serverside/configuration'
require 'engineyard-serverside/deprecation'
require 'engineyard-serverside/future'

module EY
  module Serverside
    RemoteFailure = Class.new StandardError

    def self.node
      @node ||= deep_indifferentize(JSON.parse(dna_json))
    end

    def self.dna_json
      @dna_json ||= read_encoded_dna
    end

    private # doesn't work how people think, but hey..
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

    def self.dna_path
      '/etc/chef/dna.json'
    end

    def self.read_encoded_dna
      encoded_dna = '{}'
      force_unicode = encoded_dna.respond_to?(:force_encoding)
      $KCODE = 'U' unless force_unicode

      if File.exist?(dna_path)
        encoded_dna = `sudo cat #{dna_path}`
        encoded_dna.force_encoding('UTF-8') if force_unicode
      end

      encoded_dna
    end
  end
end
