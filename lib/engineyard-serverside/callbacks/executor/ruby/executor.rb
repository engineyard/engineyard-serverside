require 'rbconfig'
require 'railway'
require 'engineyard-serverside/callbacks/executor/base'
require 'engineyard-serverside/callbacks/executor/ruby/context'

module EY
  module Serverside
    module Callbacks
      module Executor
        module Ruby

          # An executor for Ruby hooks
          class  Executor < Base
            step :validate_hook
            step :display_deprecation_warnings
            step :announce_execution
            step :context_eval

            def handle_failure(payload = {})
              case payload[:reason]

              # We tried to execute the hook, but doing so raised an exception.
              # So, let us tell you all about that and propagate the error to
              # the caller.
              when :execution_failed
                exception = payload[:exception]
                display_hook_error(exception)
                raise exception

              # A syntax error was detected in the hook, so rather than trying
              # to run it, we bail with some information for the user.
              when :syntax_error
                abort "*** [Error] Invalid Ruby syntax in hook: #{hook_path} ***\n*** #{payload[:syntax_error]} ***"

              # Something most out of the ordinary happened, to the point that
              # we don't know how to handle it. That being the case, we're going
              # to just flat out bail.
              else
                abort "*** [Error] An unknown error occurred for hook: #{hook_path} ***"
              end
            end

            def display_deprecation_warnings(input = {})
              code = input[:code]

              if code =~ /@configuration/
                shell.warning("Use of `@configuration` in deploy hooks is deprecated.\nPlease use `config`, which provides access to the same object.\n\tin #{hook_path}")
              end

              if code =~ /@node/
                shell.warning("Use of `@node` in deploy hooks is deprecated.\nPlease use `config.node`, which provides access to the same object.\n\tin #{hook_path}")
              end

              Success(input)
            end

            def announce_execution(input = {})
              shell.info "Executing #{hook.path} ..."
              Success(input)
            end

            def context_eval(input = {})
              Dir.chdir(paths.active_release.to_s) do
                begin
                  Context.new(config, shell, hook).instance_eval(input[:code])
                rescue Exception => exception
                  return Failure(
                    input.merge(
                      {
                        :reason => :execution_failed,
                        :exception => exception
                      }
                    )
                  )
                end
              end

              Success(input)
            end

            def validate_hook(input = {})
              output = `#{ruby_bin} -c #{hook_path} 2>&1`
              unless output =~ /Syntax OK/
                return Failure(
                  input.merge(
                    {
                      :reason => :syntax_error,
                      :syntax_error => output
                    }
                  )
                )
              end

              Success(input.merge({:code => hook.read}))
            end

            def ruby_bin
              # Ideally, we'd use RbConfig.ruby, but that doesn't work on 1.8.7
              File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
            end

            def display_hook_error(exception)
              shell.fatal <<-ERROR
  Exception raised in hook #{hook_path}.

  #{exception.class}: #{exception.to_s}

  Please fix this error before retrying.
              ERROR
            end

          end

        end
      end
    end
  end
end
