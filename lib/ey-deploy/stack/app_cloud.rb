module EY::Stack::AppCloud 
  class Generic < EY::Stack
    roles_for :maintenance_page, :app_master, :app, :solo
    roles_for :restart, :app_master, :app, :solo
    roles_for :migrate, :app_master, :solo
  end
  
  class NginxMongrel < Generic
    register :appcloud, :nginx_mongrel

    def uses_maintenance_page?
      true
    end

    task_overrides do
      def do_restart
        sudo("monit restart all -g #{c.app}")
      end
    end
  end

  class NginxUnicorn < Generic
    register :appcloud, :nginx_unicorn

    task_overrides do
      def do_restart
        pidfile = "/var/run/engineyard/unicorn_#{c.app}.pid"
        condition = "[ -e #{pidfile} ] && [ ! -d /proc/`cat #{pidfile}` ]"
        sudo("if #{condition}; then rm -f #{pidfile}; fi")
        sudo("/etc/init.d/unicorn_#{c.app} deploy")
      end
    end
  end

  class NginxPassenger < Generic
    register :appcloud, :nginx_passenger

    task_overrides do
      def do_restart
        sudo("touch #{c.current_path}/tmp/restart.txt")
      end
    end
  end
end
