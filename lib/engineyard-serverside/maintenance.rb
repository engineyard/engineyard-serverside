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
          raise "Cannot enable maintenance page. Application #{config.app_name} has never been deployed."
        end
      end

      def manually_disable
        if paths.deployed?
          disable
          shell.status "Maintenance page disabled"
        else
          raise "Cannot disable maintenance page. Application #{config.app_name} has never been deployed."
        end
      end

      def conditionally_enable
        if using_maintenance_page?
          enable
        else
          explain_not_enabling
        end
      end

      def conditionally_disable
        if using_maintenance_page?
          disable
        elsif exist?
          shell.status "[Attention] Maintenance page is still up.\nYou must remove it manually using `ey web enable`."
        end
      end

      protected

      attr_reader :config, :shell

      def using_maintenance_page?
        config.maintenance_on_restart? || (config.migrate? && config.maintenance_on_migrate?)
      end

      def enable
        shell.status "Enabling maintenance page."
        run "mkdir -p #{maintenance_page_dirname}"
        public_system_symlink_warning
        @up = true
        run "cp #{source_path} #{enabled_maintenance_page_pathname}"
      end

      def disable
        shell.status "Removing maintenance page."
        @up = false
        run "rm -f #{enabled_maintenance_page_pathname}"
      end

      def run(cmd)
        @servers.roles(:app_master, :app, :solo).run(cmd)
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
          shell.status "Skipping maintenance page. (maintenance_on_migrate is false in ey.yml)"
          shell.notice "[Caution] No maintenance migrations must be non-destructive!\nRequests may be served during a partially migrated state."
        elsif config.required_downtime_stack?
          shell.status "Skipping maintenance page. (maintenance_on_restart is false in ey.yml, overriding recommended default)"
        else
          shell.status "Skipping maintenance page. (no-downtime restarts supported)"
        end

        if config.required_downtime_stack? && !exist?
          shell.warning <<-WARN
No maintenance page! Brief downtime is possible during restart.
This application stack does not support no-downtime restarts.
          WARN
        end
      end

      def public_system_symlink_warning
        if paths.public_system.realpath != maintenance_page_dirname.realpath
          shell.warning <<-WARN
Current repository layout does not allow for maintenance pages!
Web traffic may still be served to your application.

Expected a symlink at #{paths.public_system}

To use maintenance pages, remove 'public/system' from your repository.
          WARN
        end
      end
    end
  end
end
