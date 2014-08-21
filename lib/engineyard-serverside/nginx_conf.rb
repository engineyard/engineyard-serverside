module EY
  module Serverside
    class NginxConf
      attr_reader :servers, :config, :shell, :runner

      def initialize(servers, config, shell, runner)
        @servers, @config, @shell, @runner = servers, config, shell, runner
      end

      def nginx_conf?
        paths.nginx_conf.exist?
      end
      
      def nginx_sysconf_dir
        "/etc/nginx/"
      end

      def custom_conf
        "#{nginx_sysconf_dir}servers/#{config.app}/custom.conf"
      end
      
      def app_current
        paths.deploy_root
      end

      def temp_dir
        "#{Dir.tmpdir}/nginx/#{paths.active_release}/"
      end
      
      def detected?
        nginx_conf?
      end

      def custom_conf?
        begin
          run "test -f '#{custom_conf}'"
          return true
        rescue EY::Serverside::RemoteFailure
          return false
        end
      end

      def enabled?
          enabled = config['nginx_conf']
          case enabled
          when 'false', false
            return false
          when 'true',  true, nil
            return true
          else
            raise "Unknown value #{enabled.inspect} for option nginx_conf. Expected [true, false]"
          end
      end

      # Create a temporary directory based on current deploy
      def make_temp_dir
        "mkdir -p #{temp_dir}"
      end

      # Copy all current nginx configuration to temp so it can be manipulated
      def copy_nginx_conf
        "cp -R #{nginx_sysconf_dir}* #{temp_dir}"
      end

      # include paths are absolute, make relative for test
      def replace_include_paths
        "sed -i 's#include #{nginx_sysconf_dir}#include #g' #{temp_dir}nginx.conf"
      end

      # Replace references to current release with active release
      def use_active_release
        "sed -i 's##{app_current}/current##{paths.active_release}#g' #{temp_dir}sites-enabled/*.conf"
      end

      # Sets up the nginx configs in a temp directory
      # with altered paths so the integrated config
      # can be tested before making it production.
      def create_testable_config
        sudo "#{make_temp_dir} && #{copy_nginx_conf} && #{replace_include_paths} && #{use_active_release}"
      end

      # Run test as sudo: some nginx files are root owned, produces error otherwise
      def test_and_cleanup
        sudo "nginx -t -c #{temp_dir}nginx.conf && rm -rf #{temp_dir}"
      end

      def nginx_configtest
        shell.status "Testing nginx configuration (nginx.conf detected)"
        create_testable_config
        test_and_cleanup
      end

      def conditionally_process
        if enabled?
          if detected?
            if custom_conf?
              shell.warning "nginx.conf detected, custom nginx rules should be placed in #{custom_conf}"
            else
              nginx_configtest
            end
          end
        end
      end

      protected
      def paths
        config.paths
      end

      def on_roles
        [:app_master, :app, :solo]
      end

      def run(cmd)
        runner.roles(on_roles) do
          runner.run(cmd)
        end
      end

      def sudo(cmd)
        runner.roles(on_roles) do
          runner.sudo(cmd)
        end
      end
    end
  end
end
