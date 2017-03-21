require 'thor'
require 'pathname'
require 'engineyard-serverside/about'
require 'engineyard-serverside/deploy'
require 'engineyard-serverside/propagator'
require 'engineyard-serverside/shell'
require 'engineyard-serverside/cli/server_hash_extractor'
require 'engineyard-serverside/servers'
require 'engineyard-serverside/cli/helpers'
require 'engineyard-serverside/cli/workflows'

module EY
  module Serverside
    module CLI

      # App is the actual Thor-based entry point for the engineyard-serverside
      # CLI application
      class App < Thor

        extend Helpers

        method_option :migrate,         :type     => :string,
                                        :desc     => "Run migrations with this deploy",
                                        :aliases  => ["-m"]

        method_option :branch,          :type     => :string,
                                        :desc     => "Git ref to deploy, defaults to master. May be a branch, a tag, or a SHA",
                                        :aliases  => %w[-b --ref --tag]

        method_option :repo,            :type     => :string,
                                        :desc     => "Remote repo to deploy",
                                        :aliases  => ["-r"]


        # Archive source strategy
        method_option :archive,        :type     => :string,
                                       :desc     => "Remote URI for archive to download and unzip"

        # Git source strategy
        method_option :git,            :type     => :string,
                                       :desc     => "Remote git repo to deploy"

        method_option :clean,          :type     => :boolean,
                                       :desc     => "Run deploy without relying on existing files"


        account_app_env_options
        config_option
        framework_env_option
        instances_options
        stack_option
        verbose_option

        desc "deploy", "Deploy code to /data/<app>"
        def deploy(default_task=:deploy)

          # By default, we'll want to perform the :deploy workflow, but this
          # method is also the entry point for the rollback workflow. So,
          # we'll just let the workflow system figure out what to do based on
          # the task passed in from the command line.
          Workflows.perform(default_task, options)
        end

        account_app_env_options
        config_option
        instances_options
        verbose_option
        desc "enable_maintenance", "Enable maintenance page (disables web access)"
        def enable_maintenance
          Workflows.perform(:enable_maintenance, options)
        end

        account_app_env_options
        config_option
        instances_options
        verbose_option
        desc "maintenance_status", "Maintenance status"
        def maintenance_status
          Workflows.perform(:maintenance_status, options)
        end

        account_app_env_options
        config_option
        instances_options
        verbose_option
        desc "disable_maintenance", "Disable maintenance page (enables web access)"
        def disable_maintenance
          Workflows.perform(:disable_maintenance, options)
        end

        method_option :release_path,  :type     => :string,
                                      :desc     => "Value for #release_path in hooks (mostly for internal coordination)",
                                      :aliases  => ["-r"]

        method_option :current_roles, :type     => :array,
                                      :desc     => "Value for #current_roles in hooks"

        method_option :current_name,  :type     => :string,
                                      :desc     => "Value for #current_name in hooks"
        account_app_env_options
        config_option
        framework_env_option
        verbose_option
        desc "hook [NAME]", "Run a particular deploy hook"
        def hook(hook_name)
          Workflows.perform(
            :hook,
            options.merge(:hook_name => hook_name)
          )
        end

        method_option :ignore_existing, :type     => :boolean,
                                        :desc     => "When syncing /data/app directory, don't overwrite destination files"
        account_app_env_options
        config_option
        framework_env_option
        instances_options
        stack_option
        verbose_option
        desc "integrate", "Integrate other instances into this cluster"
        def integrate
          Workflows.perform(:integrate, :options => options)
        end

        account_app_env_options
        instances_options
        stack_option
        verbose_option
        desc "restart", "Restart app servers, conditionally enabling maintenance page"
        def restart
          Workflows.perform(:restart, options)
        end
      end
    end
  end
end
