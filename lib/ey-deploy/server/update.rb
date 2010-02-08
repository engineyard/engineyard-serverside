require 'pp'

module EY
  module Server
    class Update
      def self.run(opts={})
        node = JSON.parse(File.read(EY::DNA_FILE))

        default_options = {
          :node => node,
        }
        pp opts

        new(default_options.merge!(opts))
      end
    end
  end
end
