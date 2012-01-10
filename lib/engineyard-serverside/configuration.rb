require 'json'
require 'thor'

module EY
  module Serverside
    class Deploy::Configuration
      DEFAULT_CONFIG = Thor::CoreExt::HashWithIndifferentAccess.new({
        "branch"         => "master",
        "strategy"       => "Git",
        "bundle_without" => "test development",
      })

      attr_reader :configuration
      alias :c :configuration

      attr_writer :release_path

      def initialize(options={})
        opts = options.dup
        @release_path = opts[:release_path]
        config = JSON.parse(opts.delete("config") || "{}")
        @configuration = DEFAULT_CONFIG.merge(config).merge(opts)
      end

      # Delegate to the configuration objects
      def method_missing(meth, *args, &blk)
        c.key?(meth.to_s) ? c[meth.to_s] : super
      end

      def respond_to?(meth, include_private=false)
        c.key?(meth.to_s) ? true : super
      end

      def [](key)
        if respond_to?(key.to_sym)
          send(key.to_sym)
        else
          c[key]
        end
      end

      def has_key?(key)
        if respond_to?(key.to_sym)
          true
        else
          c.has_key?(key)
        end
      end

      def to_json
        configuration.to_json
      end

      def node
        EY::Serverside.node
      end

      def app
        configuration['app'].to_s
      end

      def revision
        IO.read(File.join(latest_release, 'REVISION'))
      end

      def repository_cache
        configuration['repository_cache'] || File.join(deploy_to, "/shared/cached-copy")
      end

      def deploy_to
        configuration['deploy_to'] || "/data/#{app}"
      end

      def migrate?
        !!configuration['migrate']
      end

      def migration_command
        configuration['migrate'] == "migrate" ? DEFAULT_CONFIG["migrate"] : configuration['migrate']
      end

      def bundle_without
        configuration['bundle_without']
      end

      def user
        configuration['user'] || ENV['USER']
      end

      def group
        configuration['group'] || user
      end

      def role
        node['instance_role']
      end

      def current_role
        current_roles.first
      end

      def copy_exclude
        @copy_exclude ||= Array(configuration.fetch("copy_exclude", []))
      end

      def environment
        configuration['framework_env']
      end

      def latest_release
        all_releases.last
      end

      def previous_release(current=latest_release)
        index = all_releases.index(current)
        all_releases[index-1]
      end

      def oldest_release
        all_releases.first
      end

      def all_releases
        Dir.glob("#{release_dir}/*").sort
      end

      def binstubs_path
        release_path + '/ey_bundler_binstubs'
      end

      def framework_envs
        "RAILS_ENV=#{environment} RACK_ENV=#{environment} NODE_ENV=#{environment} MERB_ENV=#{environment}"
      end

      def current_path
        File.join(deploy_to, "current")
      end

      def shared_path
        File.join(deploy_to, "shared")
      end

      def bundled_gems_path
        File.join(shared_path, "bundled_gems")
      end

      def gemfile_path
        File.join(release_path, "Gemfile")
      end

      def ruby_version_file
        File.join(bundled_gems_path, "RUBY_VERSION")
      end

      def ruby_version_command
        "ruby -v"
      end

      def system_version_file
        File.join(bundled_gems_path, "SYSTEM_VERSION")
      end

      def system_version_command
        "uname -m"
      end

      def release_dir
        File.join(deploy_to, "releases")
      end

      def failed_release_dir
        File.join(deploy_to, "releases_failed")
      end

      def release_path
        @release_path ||= File.join(release_dir, Time.now.utc.strftime("%Y%m%d%H%M%S"))
      end

      def exclusions
        copy_exclude.map { |e| %|--exclude="#{e}"| }.join(' ')
      end

    end
  end
end
