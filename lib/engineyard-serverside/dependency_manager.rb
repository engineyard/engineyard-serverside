require 'engineyard-serverside/dependency_manager/base'
require 'engineyard-serverside/dependency_manager/bundler'
require 'engineyard-serverside/dependency_manager/npm'

module EY
  module Serverside
    module DependencyManager
      def self.detect(servers, config, shell, runner)
        Bundler.detect(servers, config, shell, runner) ||
          Npm.detect(servers, config, shell, runner) ||
          Base.new(servers, config, shell, runner)
      end
    end
  end
end
