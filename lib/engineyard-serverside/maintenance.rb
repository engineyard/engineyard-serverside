module EY
  module Serverside
    class Maintenance

      attr_reader :config, :shell

      def initialize(servers, config, shell)
        @servers, @config, @shell = servers, config, shell
      end

      def exist?
        enabled_maintenance_page_pathname.exist?
      end

      def up?
        @up
      end

      def status
        if exist?
          shell.info "Maintenance page: up"
        else
          shell.info "Maintenance page: down"
        end
        exist?
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

      def using_maintenance_page?
        config.maintenance_on_restart? || (config.migrate? && config.maintenance_on_migrate?)
      end

      def enable
        shell.status "Enabling maintenance page."
        run "mkdir -p #{maintenance_page_dirname}"
        public_system_symlink_warning
        @up = true
        maintenance_page_html = File.read(source_path)
        if maintenance_page_html.index("'")
          #if the html contains an aprostophe it's probably custom coming from your app so will work on app slaves even if the serverside versions mistmatch
          run "cp #{source_path} #{enabled_maintenance_page_pathname}"
        else
          #run fans out to all app servers but the serverside version is only isntalled on the server being used to deploy
          #so if the serveside version being used isn't installed on a given app server the cp command would fail, but this echo will still work
          run "echo '#{maintenance_page_html}' > #{enabled_maintenance_page_pathname}"
        end
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
        if paths.active_release.join('public','system').realpath != maintenance_page_dirname.realpath
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
