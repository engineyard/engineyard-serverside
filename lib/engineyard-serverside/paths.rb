require 'pathname'

module EY
  module Serverside
    class Paths

      module LegacyHelpers
        def self.legacy_path_helper(name, new_name)
          define_method(name) do |*a|
            paths.send(new_name, *a).to_s
          end
        end

        legacy_path_helper :deploy_to,                       :deploy_root
        legacy_path_helper :release_dir,                     :releases
        legacy_path_helper :failed_release_dir,              :releases_failed
        legacy_path_helper :release_path,                    :active_release
        legacy_path_helper :previous_release,                :previous_release
        legacy_path_helper :latest_release,                  :latest_release
        legacy_path_helper :current_path,                    :current
        legacy_path_helper :shared_path,                     :shared
        legacy_path_helper :maintenance_page_enabled_path,   :enabled_maintenance_page
        legacy_path_helper :repository_cache,                :repository_cache
        legacy_path_helper :bundled_gems_path,               :bundled_gems
        legacy_path_helper :ruby_version_file,               :ruby_version
        legacy_path_helper :system_version_file,             :system_version
        legacy_path_helper :binstubs_path,                   :binstubs
        legacy_path_helper :gemfile_path,                    :gemfile
        legacy_path_helper :ssh_identity_file,               :deploy_key

        def all_releases
          EY::Serverside.deprecation_warning("config.all_releases is deprecated. Please use 'config.paths.all_releases' which returns Pathname objects.")
          paths.all_releases.map {|path| path.to_s }
        end
      end

      # Maintenance page candidates in order of search preference.
      MAINTENANCE_CANDIDATES = [
        "public/maintenance.html.custom",
        "public/maintenance.html.tmp",
        "public/maintenance.html",
        "public/system/maintenance.html.default",
      ]

      # This one is guaranteed to exist.
      DEFAULT_MAINTENANCE_PAGE = Pathname.new("default_maintenance_page.html").expand_path(File.dirname(__FILE__))

      # Define methods that get us paths
      def self.def_path(name, parts)
        define_method(name.to_sym) { path(*parts) }
      end

      # Load a path given a root and more parts
      # Pathname#join is extremely inefficient.
      # This implementation uses much less memory and way fewer objects.
      def path(root, *parts)
        Pathname.new(File.join(send(root).to_s, *parts))
      end

      attr_reader :home, :deploy_root

      def_path :internal_key,             [:home, '.ssh', 'internal']

      def_path :current,                  [:deploy_root,    'current']
      def_path :releases,                 [:deploy_root,    'releases']
      def_path :releases_failed,          [:deploy_root,    'releases_failed']
      def_path :shared,                   [:deploy_root,    'shared']
      def_path :shared_log,               [:shared,         'log']
      def_path :shared_tmp,               [:shared,         'tmp']
      def_path :shared_config,            [:shared,         'config']
      def_path :shared_node_modules,      [:shared,         'node_modules']
      def_path :shared_system,            [:shared,         'system']
      def_path :default_repository_cache, [:shared,         'cached-copy']
      def_path :enabled_maintenance_page, [:shared_system,  'maintenance.html']
      def_path :shared_assets,            [:shared,         'assets']
      def_path :bundled_gems,             [:shared,         'bundled_gems']
      def_path :shared_services_yml,      [:shared_config,  'ey_services_config_deploy.yml']
      def_path :ruby_version,             [:bundled_gems,   'RUBY_VERSION']
      def_path :system_version,           [:bundled_gems,   'SYSTEM_VERSION']
      def_path :latest_revision,          [:latest_release, 'REVISION']
      def_path :active_revision,          [:active_release, 'REVISION']
      def_path :binstubs,                 [:active_release, 'ey_bundler_binstubs']
      def_path :gemfile,                  [:active_release, 'Gemfile']
      def_path :gemfile_lock,             [:active_release, 'Gemfile.lock']
      def_path :public,                   [:active_release, 'public']
      def_path :deploy_hooks,             [:active_release, 'deploy']
      def_path :public_assets,            [:public, 'assets']
      def_path :public_system,            [:public, 'system']
      def_path :package_json,             [:active_release, 'package.json']
      def_path :composer_json,            [:active_release, 'composer.json']
      def_path :composer_lock,            [:active_release, 'composer.lock']
      def_path :active_release_config,    [:active_release, 'config']
      def_path :active_log,               [:active_release, 'log']
      def_path :active_node_modules,      [:active_release, 'node_modules']
      def_path :active_tmp,               [:active_release, 'tmp']
      def_path :mix_ex,                   [:active_release, 'mix.exs']
      def_path :mix_lock,                 [:active_release, 'mix.lock']
      def_path :elixir_deps,              [:shared,         'deps']
      def_path :active_elixir_deps,       [:active_release, 'deps']
      def_path :elixir_rel,               [:shared,         'rel']

      def initialize(opts)
        @opts             = opts
        @home             = Pathname.new(@opts[:home] || ENV['HOME'])
        @app_name         = @opts[:app_name]
        @active_release   = Pathname.new(@opts[:active_release])   if @opts[:active_release]
        @repository_cache = Pathname.new(@opts[:repository_cache]) if @opts[:repository_cache]
        @deploy_root      = Pathname.new(@opts[:deploy_root] || "/data/#{@app_name}")
      end

      def release_dirname
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      # if active_release is already set, it's set because we're operating on
      # an existing release. This happens during integrate
      def new_release!
        @active_release ||= path(:releases, release_dirname)
      end

      # If no active release is defined, use current
      def active_release
        @active_release || latest_release
      end

      def deploy_key
        path(:home, '.ssh', "#{@app_name}-deploy-key")
      end

      def ssh_wrapper
        path(:shared_config, "#{@app_name}-ssh-wrapper")
      end

      def deploy_hook(hook_name)
        path(:deploy_hooks, "#{hook_name}.rb")
      end

      def executable_deploy_hook(hook_name)
        path(:deploy_hooks, "#{hook_name}")
      end

      def repository_cache
        @repository_cache ||= default_repository_cache
      end

      def all_releases
        @all_releases ||= Pathname.glob(path(:releases,'*')).sort
      end

      # deploy_root/releases/<release before argument release path>
      def previous_release(from_release=latest_release)
        index = all_releases.index(from_release)
        if index && index > 0
          all_releases[index-1]
        else
          nil
        end
      end

      def previous_revision
        rel = previous_release(active_release)
        rel && rel.join('REVISION')
      end

      # deploy_root/releases/<latest timestamp>
      def latest_release
        all_releases.last
      end

      def deployed?
        !!latest_release
      end

      def maintenance_page_candidates
        if latest_release
          candidates = MAINTENANCE_CANDIDATES.map do |file|
            path(:latest_release, file)
          end
        else
          candidates = []
        end
        candidates << DEFAULT_MAINTENANCE_PAGE
        candidates
      end

      def rollback
        if deployed? && previous_release
          self.class.new(@opts.dup.merge(:active_release => previous_release))
        else
          nil
        end
      end
    end
  end
end
