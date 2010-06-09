$LOAD_PATH.push File.expand_path("../lib", File.dirname(__FILE__))

Bundler.require :default, :test
require 'pp'
require 'ey-deploy'

module EY
  def self.dna_json=(j)
    @dna_json = j;
    @node = nil
    j
  end
end

Spec::Runner.configure do |config|
  config.before(:all) do
    EY.dna_json = {}.to_json
  end
end
