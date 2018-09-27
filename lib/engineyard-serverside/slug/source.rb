require 'engineyard-serverside/slug/source/updater'

module EY
  module Serverside
    module Slug
      module Source

        def self.update(data = {})
          Updater.new(data).update
        end


      end
    end
  end
end
