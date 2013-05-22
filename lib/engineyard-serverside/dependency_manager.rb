require 'engineyard-serverside/dependency_manager/base'
require 'engineyard-serverside/dependency_manager/bundler'
require 'engineyard-serverside/dependency_manager/bundler_lock'
require 'engineyard-serverside/dependency_manager/npm'
require 'engineyard-serverside/dependency_manager/composer'

module EY
  module Serverside
    module DependencyManager
      def self.detect(servers, config, shell, runner)
        Bundler.detect(servers, config, shell, runner) ||
        BundlerLock.detect(servers, config, shell, runner) ||
          Npm.detect(servers, config, shell, runner) ||
          Composer.detect(servers, config, shell, runner) ||
          Base.new(servers, config, shell, runner)
      end
    end
  end
end
