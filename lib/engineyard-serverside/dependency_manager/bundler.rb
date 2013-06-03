module EY
  module Serverside
    module DependencyManager
      class Bundler < Base
        DEFAULT_VERSION = "1.3.4"

        def self.default_version
          DEFAULT_VERSION
        end

        def detected?
          gemfile? && !lockfile?
        end

        def gemfile?
          paths.gemfile.exist?
        end

        def lockfile?
          lockfile_path.exist?
        end

        def check
          shell.warning <<-WARN
Gemfile found but Gemfile.lock is missing!
You can get different versions of gems in production than what you tested with.
You can get different versions of gems on every deployment even if your Gemfile hasn't changed.
Deploying will take longer and some deploy options will be limited.

To fix this problem, commit your Gemfile.lock to your repository and redeploy.
          WARN
        end

        def install
          check_ruby_bundler
        end

        # Without Gemfile.lock, don't do anything with sqlite3
        def uses_sqlite3?
          false
        end

        # Without Gemfile.lock, don't do anything about ey_config
        def check_ey_config
        end

        # Without Gemfile.lock, there is no determining the rails version.
        def rails_version
          nil
        end

        private

        def lockfile_path
          paths.gemfile_lock
        end

        def write_system_version
          store_ruby_version   = "#{config.ruby_version_command} > #{paths.ruby_version}"
          store_system_version = "#{config.system_version_command} > #{paths.system_version}"

          run "mkdir -p #{paths.bundled_gems} && chown #{config.user}:#{config.group} #{paths.bundled_gems}"
          run "#{store_ruby_version} && #{store_system_version}"
        end

        def check_ruby_bundler
          shell.status "Bundling gems..."
          clean_bundle_on_system_version_change
          install_bundler_gem
          run "#{clean_environment} && cd #{paths.active_release} && #{bundle_install_command}"
          write_system_version
        end

        # Install bundler in the system ruby
        def install_bundler_gem
          egrep_escaped_version = bundler_version.gsub(/\./, '\.')
          # the grep "bundler " is so that gems like bundler08 don't get
          # their versions considered too
          #
          # the [,)] is to stop us from looking for e.g. 0.9.2, seeing
          # 0.9.22, and mistakenly thinking 0.9.2 is there
          has_gem_cmd = %{gem list bundler | grep "bundler " | egrep -q "#{egrep_escaped_version}[,)]"}
          install_cmd = %{gem install bundler -q --no-rdoc --no-ri -v "#{bundler_version}"}
          sudo "#{clean_environment} && #{has_gem_cmd} || #{install_cmd}"
        end

        # GIT_SSH needs to be defined in the environment for customers with private bundler repos in their Gemfile.
        # It seems redundant to declare the env var again, but I'm hesitant to remove it right now.
        def clean_environment
          %{export GIT_SSH="#{ENV['GIT_SSH']}" && export LANG="en_US.UTF-8" && unset RUBYOPT BUNDLE_PATH BUNDLE_FROZEN BUNDLE_WITHOUT BUNDLE_BIN BUNDLE_GEMFILE}
        end

        def bundle_install_options
          options = [
            "--gemfile",  "#{paths.gemfile}",
            "--path",     "#{paths.bundled_gems}",
            "--binstubs", "#{paths.binstubs}",
          ]
          options += config.extra_bundle_install_options
          options
        end

        def bundle_install_command
          "ruby -S bundle _#{bundler_version}_ install #{bundle_install_options.join(" ")}"
        end

        def clean_bundle_on_system_version_change
          # diff exits with 0 for same and 1/2 for different/file not found.
          check_ruby   = "#{config.ruby_version_command} | diff - #{paths.ruby_version} >/dev/null 2>&1"
          check_system = "#{config.system_version_command} | diff - #{paths.system_version} >/dev/null 2>&1"
          clean_bundle = "rm -Rf #{paths.bundled_gems}"

          shell.substatus "Checking for system version changes"
          run "#{check_ruby} && #{check_system} || #{clean_bundle}"
        end

        def bundler_version
          self.class.default_version
        end
      end
    end
  end
end
