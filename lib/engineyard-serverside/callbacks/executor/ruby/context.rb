require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    module Callbacks
      module Executor
        module Ruby

          class Context
            include EY::Serverside::Shell::Helpers

            attr_reader :configuration, :shell, :hook

            def initialize(config, shell, hook)
              @configuration = config
              @configuration.set_framework_envs
              @shell = shell
              @node = config.node
              @hook = hook
            end

            def config
              @configuration
            end

            def inspect
              "#<Callbacks::Executor::Ruby::Context #{hook.path.inspect}>"
            end

            def method_missing(meth, *args, &blk)
              if config.respond_to?(meth)
                shell.warning "Use of `#{meth}` (via method_missing) is deprecated in favor of `config.#{meth}` for improved error messages and compatibility.\n\tin #{hook.path}"
                config.send(meth, *args, &blk)
              else
                super
              end
            end

            def respond_to?(*a)
              config.respond_to?(*a) || super
            end

            def run(cmd)
              shell.logged_system(Escape.shell_command(["sh", "-l", "-c", cmd])).success?
            end

            def run!(cmd)
              run(cmd) or raise("run!: Command failed. #{cmd}")
            end

            def sudo(cmd)
              shell.logged_system(Escape.shell_command(["sudo", "sh", "-l", "-c", cmd])).success?
            end

            def sudo!(cmd)
              sudo(cmd) or raise("sudo!: Command failed. #{cmd}")
            end

            # convenience functions for running on certain instance types
            def on_app_master(&blk)                 on_roles(%w[solo app_master],          &blk) end
            def on_app_servers(&blk)                on_roles(%w[solo app_master app],      &blk) end
            def on_app_servers_and_utilities(&blk)  on_roles(%w[solo app_master app util], &blk) end

            def on_utilities(*names, &blk)
              names.flatten!
              on_roles(%w[util]) do
                blk.call if names.empty? || names.include?(config.current_name)
              end
            end

            private
            def on_roles(desired_roles)
              yield if desired_roles.any? { |role| config.current_roles.include?(role) }
            end
          end

        end
      end
    end
  end
end
