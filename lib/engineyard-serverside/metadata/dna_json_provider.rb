module EY::Metadata
  class DnaJsonProvider < Provider
    def self.dna_json
      @dna_json ||= `sudo cat /etc/chef/dna.json`
    end

    def roles
      [raw[:instance_role]]
    end

    def raw
      @raw ||= deep_indifferentize(JSON.parse(self.class.dna_json))
    end

    private
    def deep_indifferentize(thing)
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
