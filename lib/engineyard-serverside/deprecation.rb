require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    def self.deprecation_warning(msg)
      $stderr.puts "DEPRECATION WARNING: #{msg}\n\t#{caller(2).first}"
    end

    def self.const_missing(const)
      if const == :LoggedOutput
        EY::Serverside.deprecation_warning("EY::Serverside::LoggedOutput has been deprecated. Use EY::Serverside::Shell::Helpers instead.")
        EY::Serverside::Shell::Helpers
      else
        super
      end
    end
  end
end
