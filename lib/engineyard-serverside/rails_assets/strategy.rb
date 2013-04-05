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

        class Private
          attr_reader :paths, :runner

          def initialize(paths, runner)
            @paths = paths
            @runner = runner
          end

          def reuse
            run("mkdir -p #{paths.public_assets} && rsync -aq #{previous_assets_path}/ #{paths.public_assets}")
          end

          # ?ink the previous assets into the new public/last_assets/assets
          # to prevent missing assets during deploy.
          #
          # This results in the directory structure:
          #   deploy_root/current/public/last_assets/assets -> deploy_root/releases/<prev>/public/assets
          def prepare
            last = paths.public.join('last_assets')
            run "mkdir -p #{last} && ln -nfs #{previous_assets_path} #{last.join('assets')}"
            yield
          end

          protected

          def run(cmd)
            runner.run(cmd)
          end

          def previous_assets_path
            paths.previous_release(paths.active_release).join('public','assets')
          end
        end

        class Shared
          attr_reader :paths, :runner
          def initialize(paths, runner)
            @paths = paths
            @runner = runner
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

            all_assets_on_disk = Dir.glob(shared_assets_path.join('**','*.*').to_s) - [manifest_path.basename.to_s]
            assets_on_disk     = all_assets_on_disk.reject {|a| a =~ /\.gz$/}
            assets_in_manifest = YAML.load_file(manifest_path.to_s).values

            (assets_on_disk - assets_in_manifest).each do |asset|
              cmd = "rm -f #{asset}"
              cmd += " #{asset}.gz" if all_assets_on_disk.include?("#{asset}.gz")
              run(cmd)
            end
          end

          def manifest_path
            shared_assets_path.join('manifest.yml')
          end
        end

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
