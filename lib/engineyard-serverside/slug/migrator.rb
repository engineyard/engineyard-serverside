require 'result'
require 'runner'

module EY
  module Serverside
    module Slug
      class Migrator
        include Result::DSL
        include Runner

        attr_reader :config, :shell

        def initialize(config, shell)
          @config = config
          @shell = shell
        end

        def call(data = {})
          return Success(data) unless config.migrate?

          cmd = "PATH=#{paths.binstubs}:$PATH #{config.framework_envs} #{config.migration_command}"

          return Failure(
            data.merge(:error => "Could not migrate database")
          ) unless Dir.chdir(paths.active_release) {run_and_success?(cmd)}

          Success(data.merge(:migrated => true))
        end

        private
        def paths
          config.paths
        end

        def self.migrate(data = {})
          new(data[:config], data[:shell]).call(data)
        end
      end
    end
  end
end
