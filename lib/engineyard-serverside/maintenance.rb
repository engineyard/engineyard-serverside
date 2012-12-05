module EY
  module Serverside
    class Maintenance

      def initialize(servers, config, shell)
        @servers, @config, @shell = servers, config, shell
      end

      def exist?
        enabled_maintenance_page_pathname.exist?
      end

      def up?
        @up
      end

      def manually_enable
        if paths.deployed?
          enable
          shell.status "Maintenance page enabled"
        else
          shell.fatal "Cannot enabled maintenance page. Application #{config.app_name} has never been deployed."
          false
        end
      end

      def manually_disable
        if paths.deployed?
          disable
          shell.status "Maintenance page disabled"
        else
          shell.fatal "Cannot enabled maintenance page. Application #{config.app_name} has never been deployed."
          false
        end
      end

      def conditionally_enable
        if config.enable_maintenance_page?
          enable
        else
          explain_not_enabling
        end
      end

      def conditionally_disable
        if config.disable_maintenance_page?
          disable
        elsif exist?
          shell.info "[Attention] Maintenance page is still up.\nYou must remove it manually using `ey web enable`."
        end
      end

      protected

      attr_reader :config, :shell

      def enable
        shell.status "Enabling maintenance page."
        @up = true
        run "mkdir -p #{maintenance_page_dirname}"
        run "cp #{source_path} #{enabled_maintenance_page_pathname}"
      end

      def disable
        shell.status "Removing maintenance page."
        @up = false
        run "rm -f #{enabled_maintenance_page_pathname}"
      end

      def run(cmd)
        @servers.roles(:app_master, :app, :solo).run(shell, cmd)
      end

      def paths
        config.paths
      end

      def source_path
        paths.maintenance_page_candidates.detect {|path| path.exist? }
      end

      def enabled_maintenance_page_pathname
        paths.enabled_maintenance_page
      end

      def maintenance_page_dirname
        enabled_maintenance_page_pathname.dirname
      end

      def explain_not_enabling
        if config.migrate?
          if !config.maintenance_on_migrate? && !config.maintenance_on_restart?
            shell.status "Skipping maintenance page. (maintenance_on_migrate is false in ey.yml)"
            shell.notice "[Caution] No maintenance migrations must be non-destructive!"
            shell.notice "Requests may be served during a partially migrated state."
          end
        else
          if config.required_downtime_stack? && !config.maintenance_on_restart?
            shell.status "Skipping maintenance page. (maintenance_on_restart is false in ey.yml, overriding recommended default)"
            unless exist?
              shell.warning <<-WARN
No maintenance page! Brief downtime may be possible during restart.
This application stack does not support no-downtime restarts.
              WARN
            end
          elsif !config.required_downtime_stack?
            shell.status "Skipping maintenance page. (no-downtime restarts supported)"
          end
        end
      end

    end
  end
end
