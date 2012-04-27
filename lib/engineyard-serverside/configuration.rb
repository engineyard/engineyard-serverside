require 'json'
require 'thor'
require 'pp'

module EY
  module Serverside
    class Deploy::Configuration
      DEFAULT_CONFIG = Thor::CoreExt::HashWithIndifferentAccess.new({
        "branch"         => "master",
        "strategy"       => "Git",
        "bundle_without" => "test development",
      })

      attr_writer :release_path

      def initialize(options={})
        opts = options.inject({}) { |h,(k,v)| h[k.to_s] = v; h }
        @release_path = opts['release_path']
        config = JSON.parse(opts.delete("config") || "{}")
        @configs = [config, opts] # low to high priority
      end

      def configuration
        @configuration ||= @configs.inject(DEFAULT_CONFIG) {|low,high| low.merge(high)}
      end
      alias :c :configuration # FIXME: awful, but someone is probably using it :(

      # Delegate to the configuration objects
      def method_missing(meth, *args, &blk)
        configuration.key?(meth.to_s) ? configuration[meth.to_s] : super
      end

      def respond_to?(meth, include_private=false)
        configuration.key?(meth.to_s) ? true : super
      end

      def load_ey_yml_data(data, shell)
        environments = data['environments']
        if environments && (env_data = environments[environment_name])
          shell.substatus "ey.yml configuration loaded for environment #{environment_name.inspect}."
          shell.debug "#{environment_name}: #{env_data.pretty_inspect}"
          @configuration = nil # reset cached configuration hash
          @configs.unshift(env_data) # insert just above default configuration
          true
        else
          shell.info "No matching ey.yml configuration found for environment #{environment_name.inspect}."
          shell.debug "ey.yml:\n#{data.pretty_inspect}"
          false
        end
      end

      def [](key)
        if respond_to?(key.to_sym)
          send(key.to_sym)
        else
          configuration[key]
        end
      end

      def has_key?(key)
        respond_to?(key.to_sym) || configuration.has_key?(key)
      end

      def to_json
        configuration.to_json
      end

      def node
        EY::Serverside.node
      end

      def verbose
        configuration['verbose']
      end

      def app
        configuration['app'].to_s
      end
      alias app_name app

      def environment_name
        configuration['environment_name'].to_s
      end

      def account_name
        configuration['account_name'].to_s
      end

      def ssh_identity_file
        "~/.ssh/#{c.app}-deploy-key"
      end

      def strategy_class
        EY::Serverside::Strategies.const_get(strategy)
      end

      def revision
        IO.read(File.join(latest_release, 'REVISION'))
      end

      def repository_cache
        configuration['repository_cache'] || File.join(deploy_to, 'shared', 'cached-copy')
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

      def current_roles
        configuration['current_roles'] || []
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

      def maintenance_page_enabled_path
        File.join(shared_path, "system", "maintenance.html")
      end

      def exclusions
        copy_exclude.map { |e| %|--exclude="#{e}"| }.join(' ')
      end

    end
  end
end
