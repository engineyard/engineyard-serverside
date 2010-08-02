module EY::Metadata
  def self.for(cloud)
    case cloud
      when 'xcloud'
        XdnaProvider.new
      when 'appcloud'
        DnaJsonProvider.new
      else
        raise "Unknown target '#{cloud}'"
    end
  end

  class Provider
    def roles
      raise "Please implement #roles in provider specific class"
    end

    def role
      roles.first
    end
  end
end

require File.join(File.dirname(__FILE__), 'metadata/dna_json_provider')
require File.join(File.dirname(__FILE__), 'metadata/xdnapi_provider')
