require 'pathname'

module EY
  module Serverside
    class Paths

      module LegacyHelpers
        def deploy_to()                     paths.deploy_root.to_s                      end
        def release_dir()                   paths.releases.to_s                         end
        def failed_release_dir()            paths.releases_failed.to_s                  end
        def release_path()                  paths.active_release.to_s                   end
        def all_releases()                  paths.all_releases.map { |path| path.to_s } end
        def previous_release(*a)            paths.previous_release(*a).to_s             end
        def latest_release()                paths.latest_release.to_s                   end
        def current_path()                  paths.current.to_s                          end
        def shared_path()                   paths.shared.to_s                           end
        def maintenance_page_enabled_path() paths.enabled_maintenance_page.to_s         end
        def repository_cache()              paths.repository_cache.to_s                 end
        def bundled_gems_path()             paths.bundled_gems.to_s                     end
        def ruby_version_file()             paths.ruby_version.to_s                     end
        def system_version_file()           paths.system_version.to_s                   end
        def binstubs_path()                 paths.binstubs.to_s                         end
        def gemfile_path()                  paths.gemfile.to_s                          end
        def active_revision()               paths.active_revision.read.strip            end
        def latest_revision()               paths.latest_revision.read.strip            end
        alias revision latest_revision
        def ssh_identity_file()             paths.ssh_identity.to_s                     end
      end

      def self.def_path(name, parts)
        define_method(name.to_sym) { path(*parts) }
      end

      def path(root, *parts)
        send(root).join(*parts)
      end

      attr_reader :home, :deploy_root

      def_path :current,                  [:deploy_root,    'current']
      def_path :releases,                 [:deploy_root,    'releases']
      def_path :releases_failed,          [:deploy_root,    'releases_failed']
      def_path :shared,                   [:deploy_root,    'shared']
      def_path :shared_log,               [:shared,         'log']
      def_path :shared_config,            [:shared,         'config']
      def_path :shared_system,            [:shared,         'system']
      def_path :enabled_maintenance_page, [:shared_system,  'maintenance.html']
      def_path :bundled_gems,             [:shared,         'bundled_gems']
      def_path :ruby_version,             [:bundled_gems,   'RUBY_VERSION']
      def_path :system_version,           [:bundled_gems,   'SYSTEM_VERSION']
      def_path :latest_revision,          [:latest_release, 'REVISION']
      def_path :active_revision,          [:active_release, 'REVISION']
      def_path :binstubs,                 [:active_release, 'ey_bundler_binstubs']
      def_path :gemfile,                  [:active_release, 'Gemfile']

      def initialize(opts)
        @opts             = opts
        @home             = Pathname.new(@opts[:hame] || ENV['HOME'])
        @app_name         = @opts[:app_name]
        @active_release   = Pathname.new(@opts[:active_release])   if @opts[:active_release]
        @repository_cache = Pathname.new(@opts[:repository_cache]) if @opts[:repository_cache]
        @deploy_root      = Pathname.new(@opts[:deploy_root] || "/data/#{@app_name}")
      end

      def ssh_identity
        path(:home, '.ssh', "#{@app_name}-deploy-key")
      end

      def repository_cache
        @repository_cache ||= path(:shared, 'cached-copy')
      end

      def active_release
        @active_release ||= path(:releases, Time.now.utc.strftime("%Y%m%d%H%M%S"))
      end

      def all_releases
        @all_releases ||= Pathname.glob(releases.join('*')).sort
      end

      # deploy_root/releases/<release before argument release path>
      def previous_release(current=latest_release)
        index = all_releases.index(current)
        if index && index > 0
          all_releases[index-1]
        else
          nil
        end
      end

      # deploy_root/releases/<latest timestamp>
      def latest_release
        all_releases.last
      end

      def rollback
        if previous_release
          self.class.new(@opts.dup.merge(:active_release => previous_release))
        else
          nil
        end
      end
    end
  end
end

