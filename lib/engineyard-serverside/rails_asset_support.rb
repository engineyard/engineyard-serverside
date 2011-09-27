module EY
  module Serverside
    module RailsAssetSupport
      def compile_assets
        roles :app_master, :app, :solo do
          rails_app = "#{c.release_path}/config/application.rb"
          asset_dir = "#{c.release_path}/app/assets"
          if File.exists?(rails_app) && File.directory?(asset_dir)
            return if app_disables_assets?(rails_app)
            if app_builds_own_assets?
              info "~> public/assets already exists, skipping pre-compilation."
              return
            end
            keep_existing_assets
            cmd = "cd #{c.release_path} && PATH=#{c.binstubs_path}:$PATH #{c.framework_envs} rake assets:precompile"
            info "~> Precompiling assets for Rails: #{cmd}"
            run(cmd)
          end
        end
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

      def bundled_rails_version(lockfile_path)
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

