require 'engineyard-serverside/cli/workflows/base'

module EY
  module Serverside
    module CLI
      module Workflows
        class IntegratingServers
          private
          def procedure
            # so that we deploy to the same place there that we have here
            integrate_options[:release_path] = current_app_dir.realpath.to_s

            # we have to deploy the same SHA there as here
            integrate_options[:branch] = current_app_dir.join('REVISION').read.strip

            # always rebundle gems on integrate to make sure the instance comes up correctly.
            integrate_options[:clean] = true

            propagate_serverside

            # We have to rsync the entire app dir, so we need all the permissions to be correct!
            owner_user = config.user
            owner_group = config.group

            chown_command = %|find #{app_dir} \\( -not -user #{owner_user} -or -not -group #{owner_group} \\) -exec chown -h #{owner_user}:#{owner_group} "{}" +|
            
            shell.logged_system("sudo sh -l -c '#{chown_command}'", servers.detect {|server| server.local?})

            servers.run_for_each! do |server|
              chown = server.command_on_server('sudo sh -l -c', chown_command)
              sync  = server.sync_directory_command(app_dir, options[:ignore_existing])
              clean = server.command_on_server('sh -l -c', "rm -rf #{current_app_dir}")
              "(#{chown}) && (#{sync}) && (#{clean})"
            end

            # deploy local-ref to other instances into /data/$app/local-current
            EY::Serverside::Deploy.new(servers, config, shell).cached_deploy
          end

          def task_name
            "integrate-#{options[:instances].join('-')}".gsub(/[^-.\w]/,'')
          end

          def integrate_options
            @integrate_options ||= options.dup
          end

          def app_dir
            @app_dir ||= Pathname.new "/data/#{options[:app]}"
          end

          def current_app_dir
            @current_app_dir ||= app_dir.join("current")
          end

        end
      end
    end
  end
end
