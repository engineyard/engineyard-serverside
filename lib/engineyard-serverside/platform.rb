module EY
  class Platform
    attr_reader :config

    def initialize(config)
      @config = config
    end

    # Other things that might belong here:
    # * GIT_SSH script
    # * git deploy ssh key for accessing the repository
    # * directory where shared config files are written? (could also be passed to the configure script)

    # Path name to install the maintenance page and trigger maintenance mode
    #
    # This is defined by nginx so it is a platform configuration.
    def maintenance_path
      config.paths.enabled_maintenance_page
    end

    def maintenance_on_restart
    end

    def check_configure
    end

    # Ideally this script would receive the pathname of the new active release as an argument
    #
    # Services should happen in the configure step, like so:
    #
    #     if which /usr/local/ey_resin/ruby/bin/ey-services-setup >/dev/null 2>&1; then
    #       /usr/local/ey_resin/ruby/bin/ey-services-setup #{app}
    #     fi
    #
    def configure_command
      configure_path = "/engineyard/bin/app_#{config.app}_configure"
      %{if [ -f "#{configure_path}" ]; then #{configure_path} #{config.paths.active_release}; fi}
    end

    def restart_command
      %{LANG="en_US.UTF-8" /engineyard/bin/app_#{config.app} deploy} # would be nice to tack on config.paths.current
    end

  end
end
