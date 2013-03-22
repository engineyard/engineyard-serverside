module EY
  module Serverside
    module RailsAssetSupport
      def compile_assets
        return unless app_needs_assets?
        rails_version = bundled_rails_version
        roles config.asset_roles do

          if app_assets_unchanged?
            shell.status "Reusing existing assets. (assets appear to be unchanged)"
            keep_existing_assets
            return
          else
            shift_existing_assets
          end

          if rails_version
            shell.status "Precompiling assets for rails v#{rails_version}"
          else
            shell.warning "Precompiling assets even though Rails was not bundled."
          end

          cmd = "cd #{paths.active_release} && PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake #{config.precompile_assets_task} RAILS_GROUPS=assets"

          begin
            run(cmd)
          rescue StandardError => e
            unshift_existing_assets
            if config.precompile_assets_inferred?
              # If specifically requested, then we want to fail if compilation fails.
              # If we are implicitly precompiling, we want to fail non-destructively
              # because we don't know if the rake task exists or if the user
              # actually intended for assets to be compiled.
              shell.warning <<-WARN
Asset compilation failure ignored!

ACTION REQUIRED: Edit your ey.yml to avoid problems:
  precompile_assets: true   # force assets to build, abort deploy on failure.
  precompile_assets: false  # never build assets.
              WARN
              return
            else
              raise
            end
          else
            if config.precompile_assets_inferred?
              shell.warning <<-WARN
Inferred asset compilation succeeded, but failures will be silently ignored!
Add 'precompile_assets: true' to ey.yml to abort deploy on failure.
              WARN
            end
          end
        end
      end

      def app_needs_assets?
        if config.precompile_assets?
          shell.status "Precompiling assets. (enabled in config)"
          return true
        elsif config.skip_precompile_assets?
          shell.status "Skipping asset precompilation. (disabled in config)"
          return false
        end

        app_rb_path = paths.active_release_config.join('application.rb')
        unless app_rb_path.readable? # Not a Rails app in the first place.
          shell.status "Skipping asset precompilation. (not a Rails application)"
          return false
        end

        if !paths.active_release.join('app','assets').exist?
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

        shell.status "Attempting Rails asset precompilation. (found directory: 'app/assets')"
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
        task_check = "PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake -T #{config.precompile_assets_task} | grep '#{config.precompile_assets_task}'"
        cmd = "cd #{paths.active_release} && #{task_check}"
        shell.logged_system("cd #{paths.active_release} && #{task_check}").success?
      end

      def app_builds_own_assets?
        paths.public_assets.exist?
      end

      def app_assets_unchanged?
        if assets_failed_path.exist?
          shell.substatus "Previous assets failed. Precompiling assets even if unchanged."
          run "rm -f #{assets_failed_path}"
          false
        elsif prev = config.previous_revision
          strategy.same?(prev, config.active_revision, 'app/assets/')
        else
          false
        end
      end

      def current_assets_path
        paths.shared_assets
      end

      def last_assets_path
        paths.shared.join('last_assets')
      end

      def assets_failed_path
        paths.shared.join('assets_failed')
      end

      # link current assets and last assets into public
      def keep_existing_assets
        run "mkdir -p #{current_assets_path} #{last_assets_path}"
        link_assets
      end

      # If there are current shared assets, move them under a 'last_assets' directory.
      #
      # To support operations like Unicorn's hot reload, it is useful to have
      # the prior release's assets as well. Otherwise, while a deploy is running,
      # clients may request stale assets that you just deleted.
      # Making use of this requires a properly-configured front-end HTTP server.
      def shift_existing_assets
        run <<-COMMAND.chomp
if [ -d #{current_assets_path} ]; then
  rm -rf #{last_assets_path} && mkdir -p #{last_assets_path} && mv #{current_assets_path} #{last_assets_path} && mkdir -p #{current_assets_path};
else
  mkdir -p #{current_assets_path} #{last_assets_path};
fi;
        COMMAND
        link_assets
      end

      # Restore share/last_assets to shared/assets and relink them to the app public
      def unshift_existing_assets
        run "touch #{assets_failed_path} && rm -rf #{current_assets_path} && mv #{last_assets_path} #{current_assets_path} && mkdir -p #{last_assets_path}"
        link_assets
      end

      def link_assets
        run "ln -nfs #{current_assets_path} #{last_assets_path} #{paths.public}"
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

