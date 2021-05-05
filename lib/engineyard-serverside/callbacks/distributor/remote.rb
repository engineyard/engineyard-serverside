module EY
  module Serverside
    module Callbacks
      module Distributor

        class Remote
          attr_reader :runner, :hook

          def self.distribute(runner, hook)
            new(runner, hook).distribute
          end

          def initialize(runner, hook)
            @runner = runner
            @hook = hook
          end

          def distribute
            shell.status "Running deploy hook: #{hook}"

            runner.run escaped_command(hook) do |server, cmd|
              instance_args = [
                '--current-roles', server.roles.to_a.join(' ')
              ]

              if server.name
                instance_args.push('--current-name')
                instance_args.push(server.name.to_s)
              end

              instance_args.push('--config')
              instance_args.push(config.to_json)

              cmd << " " << Escape.shell_command(instance_args)
            end
          end

          private
          def config
            runner.config
          end

          def shell
            runner.shell
          end

          def paths
            runner.paths
          end

          def escaped_command(hook)
            Escape.shell_command(command_for(hook))
          end

          def command_for(hook_name)
            cmd = [
              About.binary,
              'hook', hook_name.to_s,
              '--app', config.app,
              '--environment-name', config.environment_name,
              '--account-name', config.account_name,
              '--release-path', paths.active_release.to_s,
              '--framework-env', config.framework_env.to_s
            ]

            cmd.push('--verbose') if config.verbose

            cmd
          end
        end

      end
    end
  end
end

