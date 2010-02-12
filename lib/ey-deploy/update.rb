module EY
  class Update
    def self.run(opts={})
      node = JSON.parse(File.read(EY::DNA_FILE))

      default_options = {
        :node => node,
      }

      new(default_options.merge!(opts)).update
    end
  end
end
