require 'result'

module EY
  module Serverside
    module Slug

      module Generator
        extend Result::DSL

        def self.generate(data = {})
          data[:shell].logged_system(ogun(data)).success? ?
            Success(data.merge(:generated => true)) :
            Failure(data.merge(:error => "Ogun build failed"))
        end

        def self.ogun(data = {})
          [
            "/engineyard/bin/ogun",
            "build",
            data[:app_name],
            "--release",
            data[:release_name]
          ].join(' ')
        end
      end

    end
  end
end
