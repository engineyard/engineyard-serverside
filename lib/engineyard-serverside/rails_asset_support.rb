module EY
  module Serverside
    module RailsAssetSupport
      def compile_assets
        asset_dir = "#{c.release_path}/app/assets"
        return unless app_needs_assets?
        rails_version = bundled_rails_version
        roles :app_master, :app, :solo do
          keep_existing_assets
          cmd = "cd #{c.release_path} && PATH=#{c.binstubs_path}:$PATH #{c.framework_envs} rake assets:precompile"
          if rails_version
            info "~> Precompiling assets for rails v#{rails_version}"
          else
            warning "Precompiling assets even though Rails was not bundled."
          end
          run(cmd)
        end
      end

      def app_needs_assets?
        app_rb_path = File.join(c.release_path, 'config', 'application.rb')
        return unless File.readable?(app_rb_path) # Not a Rails app in the first place.
        return unless File.directory?(File.join(c.release_path, 'app', 'assets'))
        if app_builds_own_assets?
          info "~> public/assets already exists, skipping pre-compilation."
          return
        end
        if app_disables_assets?(app_rb_path)
          info "~> application.rb has disabled asset compilation. Skipping."
          return
        end
# This check is very expensive, and has been deemed not worth the time.
# Leaving this here in case someone comes up with a faster way.
=begin
        unless app_has_asset_task?
          info "~> No 'assets:precompile' Rake task found. Skipping."
          return
        end
=end
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
        task_check = "PATH=#{c.binstubs_path}:$PATH #{c.framework_envs} rake -T assets:precompile |grep 'assets:precompile'"
        cmd = "cd #{c.release_path} && #{task_check}"
        logged_system "cd #{c.release_path} && #{task_check}"
        $? == 0
      end

      def app_builds_own_assets?
        File.directory?(File.join(c.release_path, 'public', 'assets'))
      end

      # To support operations like Unicorn's hot reload, it is useful to have
      # the prior release's assets as well. Otherwise, while a deploy is running,
      # clients may request stale assets that you just deleted.
      # Making use of this requires a properly-configured front-end HTTP server.
      def keep_existing_assets
        current = File.join(c.shared_path, 'assets')
        last_asset_path = File.join(c.shared_path, 'last_assets')
        # If there are current shared assets, move them under a 'last_assets' directory.
        run <<-COMMAND
if [ -d #{current} ]; then
  rm -rf #{last_asset_path} && mkdir #{last_asset_path} && mv #{current} #{last_asset_path} && mkdir -p #{current};
else
  mkdir -p #{current} #{last_asset_path};
fi;
ln -nfs #{current} #{last_asset_path} #{c.release_path}/public
        COMMAND
       end

      def bundled_rails_version(lockfile_path = nil)
        lockfile_path ||= File.join(c.release_path, 'Gemfile.lock')
        lockfile = File.open(lockfile_path) {|f| f.read}
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

