require 'engineyard-serverside/rails_assets/strategy'
require 'forwardable'

module EY
  module Serverside
    class RailsAssets
      extend Forwardable

      def self.detect_and_compile(*args)
        new(*args).detect_and_compile
      end

      attr_reader :config, :shell, :runner

      def initialize(config, shell, runner)
        @config, @shell, @runner = config, shell, runner
      end

      def_delegators :config,
        :paths, :asset_dependencies, :asset_roles,
        :framework_envs, :precompile_assets?, :skip_precompile_assets?,
        :precompile_unchanged_assets?, :precompile_assets_task

      def detect_and_compile
        runner.roles asset_roles do
          if precompile_assets?
            if precompile_unchanged_assets?
              shell.status "Precompiling assets without change detection. (precompile_unchanged_assets: true)"
              run_precompile_assets_task
            elsif reuse_assets?
              shell.status "Reusing existing assets. (configured asset_dependencies unchanged from #{previous_revision[0,7]}..#{active_revision[0,7]})"
              asset_strategy.reuse
            else
              shell.status "Precompiling assets. (precompile_assets: true)"
              run_precompile_assets_task
            end
          elsif skip_precompile_assets?
            shell.status "Skipping asset precompilation. (precompile_assets: false)"
          elsif !application_rb_path.readable? || !app_assets_path.directory?
            # Not a Rails app. Ignore assets completely.
          elsif app_disables_assets?
            shell.status "Skipping asset precompilation. ('config/application.rb' disables assets.)"
          elsif paths.public_assets.exist?
            shell.status "Skipping asset precompilation. ('public/assets' directory already exists.)"
          else
            shell.status "Precompiling assets. ('#{app_assets}' exists, 'public/assets' not found, not disabled in config.)"
            precompile_detected_assets
          end
        end
      end

      def run_precompile_assets_task
        asset_strategy.prepare do
          cd   = "cd #{paths.active_release}"
          task = "PATH=#{paths.binstubs}:$PATH #{framework_envs} rake #{precompile_assets_task} RAILS_GROUPS=assets"
          runner.run "#{cd} && #{task}"
        end
      end

      def previous_revision
        @previous_revision ||= config.previous_revision
      end

      def active_revision
        @active_revision ||= config.active_revision
      end

      # Note on reusing assets when assets may fail silently:
      # It's difficult and error prone to reuse assets that may have failed
      # silently in the previous deploy. If the assets are unchanged during
      # this deploy, but failed last deploy, we would incorrectly reuse
      # silentely failed assets. Only reusing when assets are enabled
      # ensures that existing assets were successful.
      def reuse_assets?
        asset_strategy.reusable? &&
          previous_revision &&
          active_revision &&
          runner.unchanged_diff_between_revisions?(previous_revision, active_revision, asset_dependencies)
      end

      def precompile_detected_assets
        if !runner.rails_application?
          shell.warning "Precompiling assets even though Rails was not bundled."
        end

        run_precompile_assets_task

        shell.warning <<-WARN
Assets were detected and precompiled for this application,
but asset precompile failures may be silently ignored in the future.

ACTION REQUIRED: Add or update config/ey.yml in your project to
ensure assets are compiled every deploy and halted on failure.

  precompile_assets: true  # precompile assets

This warning will continue until you update and commit config/ey.yml.
        WARN
      rescue EY::Serverside::RemoteFailure => e
        # If we are implicitly precompiling, we want to fail non-destructively
        # because we don't know if the rake task exists or if the user
        # actually intended for assets to be compiled.
        if e.to_s =~ /Don't know how to build task '#{precompile_assets_task}'/
          shell.warning <<-WARN
Asset precompilation detected but compilation failure ignored!
Rake task '#{precompile_assets_task}' was not found.

ACTION REQUIRED: Add precompile_assets option to ey.yml.
  precompile_assets: false # disable assets to avoid this error.
          WARN
        else
          shell.error <<-ERROR
Asset precompilation detected but compilation failed!

ACTION REQUIRED: Add precompile_assets option to ey.yml.
  precompile_assets: true  # precompile assets when asset changes detected
  precompile_assets: false # disable asset compilation.
          ERROR
          raise
        end
      end

      def app_disables_assets?
        application_rb_path.open do |fd|
          fd.grep(/^[^#]*config\.assets\.enabled\s*=\s*(false|nil)/).any?
        end
      end

      # This check is very expensive, and has been deemed not worth the time.
      # Leaving this here in case someone comes up with a faster way.
      #
      # Runs 'rake -T' to see if there is an assets:precompile task.
      def app_has_asset_task?
        # We just run this locally on the app master; everybody else should
        # have the same code anyway.
        task_check = "PATH=#{paths.binstubs}:$PATH #{framework_envs} rake -T #{precompile_assets_task} | grep '#{precompile_assets_task}'"
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

      def asset_strategy
        @asset_strategy ||= RailsAssets::Strategy.fetch(config.asset_strategy, paths, runner)
      end
    end
  end
end
