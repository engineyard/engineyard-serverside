module EY
  module Serverside
    module RailsAssetSupport
      def compile_assets
        return unless app_needs_assets?
        rails_version = bundled_rails_version
        roles :app_master, :app, :solo do
          keep_existing_assets
          cmd = "cd #{paths.active_release} && PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake assets:precompile"

          if rails_version
            shell.status "Precompiling assets for rails v#{rails_version}"
          else
            shell.warning "Precompiling assets even though Rails was not bundled."
          end

          begin
            run(cmd)
          rescue StandardError => e
            if config.precompile_assets_inferred?
              # If specifically requested, then we want to fail if compilation fails.
              # If we are implicitly precompiling, we want to fail non-destructively
              # because we don't know if the rake task exists or if the user
              # actually intended for assets to be compiled.
              shell.notice "Asset compilation failure ignored.\nAdd 'precompile_assets: true' to ey.yml to abort deploy on failure."
              return
            else
              raise
            end
          end
        end
      end

      def app_needs_assets?
        if config.precompile_assets?
          shell.status "Attempting Rails asset precompilation. (enabled in config)"
          return true
        elsif config.skip_precompile_assets?
          shell.status "Skipping asset precompilation. (disabled in ey.yml)"
          return false
        end

        app_rb_path = paths.active_release_config.join('application.rb')
        unless app_rb_path.readable? # Not a Rails app in the first place.
          shell.status "Skipping asset precompilation. (not a Rails application)"
          return false
        end

        if paths.active_release.join('app','assets').exist?
          shell.status "Attempting Rails asset precompilation. (found directory: 'app/assets')"
        else
          shell.status "Skipping asset precompilation. (directory not found: 'app/assets')"
          return false
        end

        if paths.public_assets.exist?
          shell.status "Skipping asset compilation. Already compiled. (found directory: 'public/assets')"
          return false
        end

        if app_disables_assets?(app_rb_path)
          shell.status "Skipping asset compilation. (application.rb has disabled asset compilation)"
          return false
        end

        # This check is very expensive, and has been deemed not worth the time.
        # Leaving this here in case someone comes up with a faster way.
        #unless app_has_asset_task?
        #  shell.status "No 'assets:precompile' Rake task found. Skipping."
        #  return
        #end

        true
      end

      def app_disables_assets?(path)
        disabled = nil
        File.open(path) do |fd|
          pattern = /^[^#].*config\.assets\.enabled\s+=\s+(false|nil)/
          contents = fd.read
          disabled = contents.match(pattern)
        end
        disabled
      end

      # Runs 'rake -T' to see if there is an assets:precompile task.
      def app_has_asset_task?
        # We just run this locally on the app master; everybody else should
        # have the same code anyway.
        task_check = "PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake -T assets:precompile |grep 'assets:precompile'"
        cmd = "cd #{paths.active_release} && #{task_check}"
        shell.logged_system("cd #{paths.active_release} && #{task_check}").success?
      end

      def app_builds_own_assets?
        paths.public_assets.exist?
      end

      # To support operations like Unicorn's hot reload, it is useful to have
      # the prior release's assets as well. Otherwise, while a deploy is running,
      # clients may request stale assets that you just deleted.
      # Making use of this requires a properly-configured front-end HTTP server.
      def keep_existing_assets
        current = paths.shared_assets
        last_asset_path = paths.shared.join('last_assets')
        # If there are current shared assets, move them under a 'last_assets' directory.
        run <<-COMMAND
if [ -d #{current} ]; then
  rm -rf #{last_asset_path} && mkdir #{last_asset_path} && mv #{current} #{last_asset_path} && mkdir -p #{current};
else
  mkdir -p #{current} #{last_asset_path};
fi;
ln -nfs #{current} #{last_asset_path} #{paths.public}
        COMMAND
       end

      def bundled_rails_version(lockfile_path = paths.gemfile_lock)
        return unless lockfile_path.exist?
        lockfile = lockfile_path.read
        lockfile.each_line do |line|
          # scan for gemname (version) toplevel deps.
          # Likely doesn't handle ancient Bundler versions, but
          # we only call this when something looks like it is Rails 3.
          next unless line =~ /^\s{4}([-\w_.0-9]+)\s*\((.*)\)/
          return $2 if $1 == 'rails'
        end
        nil
      end
    end
  end
end

