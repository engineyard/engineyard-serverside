module EY
  module Serverside
    module RailsAssetSupport
      def compile_assets
        roles config.asset_roles do
          assets_needed = app_needs_assets?
          useable_last_assets = check_last_assets
          !assets_needed || (useable_last_assets && reuse_last_assets) || compile_fresh_assets
        end
      end

      def compile_fresh_assets
        if config.precompile_unchanged_assets?
          shell.status "Precompiling assets without change detection. (precompile_unchanged_assets: true)"
        elsif config.precompile_assets?
          shell.status "Precompiling assets. (precompile_assets: true)"
        else
          shell.status "Precompiling assets. ('#{app_assets}' exists, 'public/assets' not found, not disabled in config.)"
          if !dependency_manager.rails_version
            shell.warning "Precompiling assets even though Rails was not bundled."
          end
        end

        handle_errors do
          manage_asset_links do
            run "cd #{paths.active_release} && PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake #{config.precompile_assets_task} RAILS_GROUPS=assets"
          end
        end
      end

      def manage_asset_links
        shift_existing_assets
        begin
          yield
        rescue
          unshift_existing_assets
          raise
        end
      end

      def handle_errors
        if !config.precompile_assets_inferred?
          yield
        else
          begin
            yield
          rescue EY::Serverside::RemoteFailure => e
            # If we are implicitly precompiling, we want to fail non-destructively
            # because we don't know if the rake task exists or if the user
            # actually intended for assets to be compiled.
            #
            if e.to_s =~ /Don't know how to build task '#{config.precompile_assets_task}'/
              shell.warning <<-WARN
Asset precompilation detected but compilation failure ignored!
Rake task '#{config.precompile_assets_task}' was not found.

ACTION REQUIRED: Add precompile_assets option to ey.yml.
  precompile_assets: false # disable assets to avoid this error.
              WARN
            else
              shell.error <<-WARN
Asset precompilation detected but compilation failed!

ACTION REQUIRED: Add precompile_assets option to ey.yml.
  precompile_assets: true  # precompile assets when #{app_assets} changes.
  precompile_assets: false # disable asset compilation.
              WARN
              raise
            end
          else
            shell.warning <<-WARN
Inferred asset compilation succeeded, but failures may be silently ignored!

ACTION REQUIRED: Add precompile_assets option to ey.yml.
  precompile_assets: true  # precompile assets when #{app_assets} changes.
            WARN
          end
        end
      end

      def app_needs_assets?
        if config.precompile_assets?
          true
        elsif config.skip_precompile_assets?
          shell.status "Skipping asset precompilation. (precompile_assets: false)"
          false
        elsif !application_rb_path.readable? || !app_assets_path.directory?
          # Not a Rails app. Ignore assets completely.
          false
        elsif app_disables_assets?
          shell.status "Skipping asset precompilation. ('config/application.rb' disables assets.)"
          false
        elsif app_builds_own_assets?
          shell.status "Skipping asset precompilation. ('public/assets' directory already exists.)"
          false
        else
          true
        end
      end

      def check_last_assets
        if assets_failed_path.exist?
          run "rm -f #{assets_failed_path}"
          false
        else
          true
        end
      end

      # Returns true if reusing assets, false otherwise
      def reuse_last_assets
        return false if config.precompile_unchanged_assets?

        prev = config.previous_revision
        act = config.active_revision
        if prev && strategy.same?(prev, act, app_assets)
          # Reuse assets if they did not fail previously and the app/assets
          # directory has not had changes since last successful deploy.
          shell.status "Reusing existing assets. ('#{app_assets}' unchanged from #{prev[0,7]}..#{act[0,7]})"
          keep_existing_assets
          true
        else
          false
        end
      end

      def app_disables_assets?
        application_rb_path.open do |fd|
          fd.grep(/^[^#]*config\.assets\.enabled\s*=\s*(false|nil)/).any?
        end
      end

      def app_builds_own_assets?
        paths.public_assets.exist?
      end

      # This check is very expensive, and has been deemed not worth the time.
      # Leaving this here in case someone comes up with a faster way.
      #
      #   unless app_has_asset_task?
      #     shell.status "No 'assets:precompile' Rake task found. Skipping."
      #     return
      #   end
      #
      # Runs 'rake -T' to see if there is an assets:precompile task.
      def app_has_asset_task?
        # We just run this locally on the app master; everybody else should
        # have the same code anyway.
        task_check = "PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake -T #{config.precompile_assets_task} | grep '#{config.precompile_assets_task}'"
        cmd = "cd #{paths.active_release} && #{task_check}"
        shell.logged_system(cmd).success?
      end

      def application_rb_path
        paths.active_release.join('config','application.rb')
      end

      def app_assets
        File.join('app','assets')
      end

      def app_assets_path
        paths.active_release.join(app_assets)
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
    end
  end
end

