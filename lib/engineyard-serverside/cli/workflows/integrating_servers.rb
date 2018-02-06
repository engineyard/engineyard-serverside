require 'engineyard-serverside/cli/workflows/base'

module EY
  module Serverside
    module CLI
      module Workflows

        # IntegratingServers is a Workflow that attempts to integrate new
        # servers into an existing environment
        class IntegratingServers < Base
          private
          def procedure
            set_up_extra_options

            propagate_serverside

            chown_sync_clean
            
            # deploy local-ref to other instances into /data/$app/local-current
            deployer.cached_deploy
          end

          def set_up_extra_options
            # We want to target the current release
            options[:release_path] = current_app_dir.realpath.to_s

            # We also want to target the currently released revision
            options[:branch] = current_app_dir.join('REVISION').read.strip

            # Always rebundle gems on integrate to make sure the instance comes up correctly
            options[:clean] = true
          end

          def chown_sync_clean
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

          end

          def task_name
            "integrate-#{options[:instances].join('-')}".gsub(/[^-.\w]/,'')
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
