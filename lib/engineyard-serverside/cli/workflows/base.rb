require 'engineyard-serverside/about'
require 'engineyard-serverside/cli/server_hash_extractor'
require 'engineyard-serverside/cli/workflows/errors'
require 'engineyard-serverside/configuration'

module EY
  module Serverside
    module CLI
      module Workflows

        # Base is the template from which all Workflows are derived
        class Base
          attr_reader :options

          def initialize(options = {})
            @options = options
          end

          def perform
            shell.debug "Initializing #{About.name_with_version}."

            begin
              procedure
            rescue EY::Serverside::RemoteFailure => remote_error
              shell.fatal(remote_error.message)
              raise
            rescue Exception => error
              shell.fatal("#{error.backtrace[0]}: #{error.message} (#{error.class})")
              raise
            end
          end

          def self.perform(options = {})
            new(options).perform
          end

          private
          def config
            @config ||= EY::Serverside::Deploy::Configuration.new(options)
          end

          def shell
            @shell ||= EY::Serverside::Shell.new(
              :verbose => config.verbose,
              :log_path => File.join(
                ENV['HOME'],
                "#{config.app}-#{task_name}.log"
              )
            )
          end

          def servers
            @servers ||= EY::Serverside::Servers.from_hashes(
              EY::Serverside::CLI::ServerHashExtractor.hashes(options, config),
              shell
            )
          end

          def task_name
            raise Undefined.new(
              "You must define the private task_name method for your workflow."
            )
          end

          def procedure
            raise Undefined.new(
              "You must define the private procedure method for your workflow."
            )
          end

          def propagate_serverside
            EY::Serverside::Propagator.propagate(servers, shell)
          end
        end
      end
    end
  end
end
