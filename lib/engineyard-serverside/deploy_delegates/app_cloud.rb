module EY::DeployDelegate
  class AppCloud < Base
    register 'appcloud'

    def migrate_roles
      [ :app_master, :solo ]
    end

    def maintenance_page_roles
      restart_roles
    end

    def restart_roles
      [:app_master, :app, :solo]
    end

    def restart
      case deploy.config.stack
        when "nginx_unicorn"
          pidfile = "/var/run/engineyard/unicorn_#{deploy.config.app}.pid"
          condition = "[ -e #{pidfile} ] && [ ! -d /proc/`cat #{pidfile}` ]"
          deploy.run("if #{condition}; then rm -f #{pidfile}; fi")
          deploy.run("/engineyard/bin/app_#{deploy.config.app} deploy")
        when "nginx_mongrel"
          deploy.sudo("monit restart all -g #{deploy.config.app}")
        when "nginx_passenger"
          deploy.run("touch #{deploy.config.current_path}/tmp/restart.txt")
        else
          raise "Unknown stack #{deploy.config.stack}; restart failed!"
      end
    end
  end
end
