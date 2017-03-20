require 'engineyard-serverside/cli/workflows/calling_deploy_hooks'
require 'engineyard-serverside/cli/workflows/deploying_applications'
require 'engineyard-serverside/cli/workflows/disabling_maintenance'
require 'engineyard-serverside/cli/workflows/enabling_maintenance'
require 'engineyard-serverside/cli/workflows/integrating_servers'
require 'engineyard-serverside/cli/workflows/restarting_applications'
require 'engineyard-serverside/cli/workflows/rolling_back_applications'
require 'engineyard-serverside/cli/workflows/showing_maintenance_status'

module EY
  module Serverside
    module CLI
      module Workflows
        DEFINED = {
          :deploy => DeployingApplications,
          :disable_maintenance => DisablingMaintenance,
          :enable_maintenance => EnablingMaintenance,
          :hook => CallingDeployHooks,
          :integrate => IntegratingServers,
          :maintenance_status => ShowingMaintenanceStatus,
          :restart => RestartingApplications,
          :rollback => RollingBackApplications
        }

        def self.perform(workflow, options = {})
          resolve(workflow).
            perform(options)
        end

        def self.resolve(workflow)
          (DEFINED[normalized(workflow)] || Base)
        end

        def self.normalized(workflow)
          return nil if workflow.nil?

          workflow.to_sym
        end
      end
    end
  end
end
