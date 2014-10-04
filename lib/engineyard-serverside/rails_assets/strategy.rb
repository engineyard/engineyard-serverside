require 'yaml'

module EY
  module Serverside
    class RailsAssets
      module Strategy
        def self.all
          {
            'shared'   => Shared,
            'cleaning' => Cleaning,
            'private'  => Private,
            'shifting' => Shifting,
          }
        end

        def self.fetch(name, *args)
          (all[name.to_s] || Shifting).new(*args)
        end


        # Precompile assets fresh every time. Shared assets are not symlinked
        # and assets stay with the release that compiled them. The assets of
        # the previous deploy are symlinked as into the current deploy to
        # prevent errors during deploy.
        #
        # When no assets changes are detected, the deploy uses rsync to copy
        # the previous release's assets into the current assets directory.
        class Private
          attr_reader :paths, :runner

          def initialize(paths, runner)
            @paths = paths
            @runner = runner
          end

          def reusable?
            previous_assets_path && previous_assets_path.entries.any?
          end

          def reuse
            run "mkdir -p #{paths.public_assets} && rsync -aq #{previous_assets_path}/ #{paths.public_assets}"
          end

          # link the previous assets into the new public/last_assets/assets
          # to prevent missing assets during deploy.
          #
          # This results in the directory structure:
          #   deploy_root/current/public/last_assets/assets -> deploy_root/releases/<prev>/public/assets
          def prepare
            if previous_assets_path
              last = paths.path(:public,'last_assets')
              run "mkdir -p #{last} && ln -nfs #{previous_assets_path} #{last.join('assets')}"
            end

            yield
          end

          protected

          def run(cmd)
            runner.run cmd
          end

          # Just to be safe, we don't check the real path until runtime
          # to make sure the relevant directories are there.
          def previous_assets_path
            return @previous_assets_path if defined? @previous_assets_path
            if prev = paths.previous_release(paths.active_release)
              @previous_assets_path = prev.join('public','assets')
              @previous_assets_path = nil unless @previous_assets_path.directory?
            else
              @previous_assets_path = nil
            end
            @previous_assets_path
          end
        end

        # Basic shared assets.
        # Precompiled assets go into a single shared assets directory. The
        # assets directory is never cleaned, so a deploy hook should be used
        # to clean assets appropriately.
        #
        # When no assets changes are detected, shared directory is only
        # symlinked and precompile task is not run.
        class Shared
          attr_reader :paths, :runner
          def initialize(paths, runner)
            @paths = paths
            @runner = runner
          end

          def reusable?
            shared_assets_path.directory? && shared_assets_path.entries.any?
          end

          def reuse
            run "mkdir -p #{shared_assets_path} && ln -nfs #{shared_assets_path} #{paths.public}"
          end

          def prepare
            reuse
            yield
          end

          protected

          def run(cmd)
            runner.run(cmd)
          end

          def shared_assets_path
            paths.shared_assets
          end
        end

        # Precompiled assets are shared across all deploys like Shared.
        # Before compiling the active deploying assets, all assets that are not
        # referenced by the manifest.yml from the previous deploy are removed.
        # After cleaning, the new assets are compiled over the top. The result
        # is an assets dir that contains the last assets and the current assets.
        #
        # When no assets changes are detected, shared directory is only
        # symlinked and cleaning and precompile tasks are not run.
        class Cleaning < Shared
          def prepare
            reuse
            remove_old_assets
            yield
          rescue
            # how do you restore back to the old assets if some have been overwritten?
            # probably just deploy again I suppose.
            raise
          end

          protected

          def remove_old_assets
            return unless manifest_path.readable?

            Dir.chdir(shared_assets_path)

            all_assets_on_disk = Dir.glob(shared_assets_path.join('**','*.*').to_s) - [manifest_path.to_s]
            $stderr.puts "all_assets_on_disk #{all_assets_on_disk.inspect}"
            assets_on_disk     = all_assets_on_disk.reject {|a| a =~ /\.gz$/}
            $stderr.puts "assets_on_disk #{assets_on_disk.inspect}"
            assets_in_manifest = YAML.load_file(manifest_path.to_s).values
            $stderr.puts "assets_in_manifest #{assets_in_manifest.inspect}"

            remove_assets = []
            (assets_on_disk - assets_in_manifest).each do |asset|
              remove_assets << "'#{asset}'"
              remove_assets << "'#{asset}.gz'" if all_assets_on_disk.include?("#{asset}.gz")
            end
            run("rm -rf #{remove_assets.join(' ')}")
          end

          def manifest_path
            shared_assets_path.join('manifest.yml')
          end
        end

        # The default behavior and the one used since the beginning of asset
        # support in engineyard-serverside. Assets are compiled into a fresh
        # shared directory. Previous shared assets are shifted to a last_assets
        # directory to prevent errors during deploy.
        #
        # When no assets changes are detected, the two shared directories are
        # symlinked into the active release without any changes.
        class Shifting < Shared
          # link shared/assets and shared/last_assets into public
          def reuse
            run "mkdir -p #{shared_assets_path} #{last_assets_path} && #{link_assets}"
          end

          def prepare
            shift_existing_assets
            yield
          rescue
            unshift_existing_assets
            raise
          end

          protected

          def last_assets_path
            paths.shared.join('last_assets')
          end

          # If there are current shared assets, move them under a 'last_assets' directory.
          #
          # To support operations like Unicorn's hot reload, it is useful to have
          # the prior release's assets as well. Otherwise, while a deploy is running,
          # clients may request stale assets that you just deleted.
          # Making use of this requires a properly-configured front-end HTTP server.
          #
          # Note: This results in the directory structure:
          #   deploy_root/current/public/assets -> deploy_root/shared/assets
          #   deploy_root/current/public/last_assets -> deploy_root/shared/last_assets
          # where last_assets has an assets dir under it.
          #   deploy_root/shared/last_assets/assets
          def shift_existing_assets
            run "rm -rf #{last_assets_path} && mkdir -p #{shared_assets_path} #{last_assets_path} && mv #{shared_assets_path} #{last_assets_path.join('assets')} && mkdir -p #{shared_assets_path} && #{link_assets}"
          end

          # Restore shared/last_assets to shared/assets and relink them to the app public
          def unshift_existing_assets
            run "rm -rf #{shared_assets_path} && mv #{last_assets_path.join('assets')} #{shared_assets_path} && mkdir -p #{last_assets_path} && #{link_assets}"
          end

          def link_assets
            "ln -nfs #{shared_assets_path} #{last_assets_path} #{paths.public}"
          end
        end
      end
    end
  end
end
