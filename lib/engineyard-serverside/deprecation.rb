module EY
  module Serverside
    def self.deprecation_warning(msg)
      STDERR.puts "DEPRECATION WARNING: #{msg}"      
    end
  end
  
  def self.const_missing(const)
    if EY::Serverside.const_defined?(const)
      EY::Serverside.deprecation_warning("EY::#{const} has been deprecated. use EY::Serverside::#{const} instead")
      EY::Serverside.class_eval(const.to_s)
    else
      super
    end
  end
  
  def self.node
    EY::Serverside.deprecation_warning("EY.node has been deprecated. use EY::Serverside.node instead")
    EY::Serverside.node
  end

  def self.dna_json
    EY::Serverside.deprecation_warning("EY.dna_json has been deprecated. use EY::Serverside.dna_json instead")
    EY::Serverside.dna_json
  end

end