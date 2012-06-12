require 'json'
require 'thor'
require 'pp'
require 'engineyard-serverside/paths'

module EY
  module Serverside
    class Deploy::Configuration
      include Paths::LegacyHelpers

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
        configuration.key?(meth.to_s) || super
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

      def strategy_class
        EY::Serverside::Strategies.const_get(strategy)
      end

      def paths
        @paths ||= Paths.new({
          :hame             => @home,
          :app_name         => app_name,
          :deploy_root      => configuration['deploy_to'],
          :active_release   => @release_path,
          :repository_cache => configuration['repository_cache'],
        })
      end

      def rollback_paths!
        if rollback_paths = paths.rollback
          @paths = rollback_paths
        else
          nil
        end
      end

      def revision
        paths.revision.read
      end

      def ruby_version_command
        "ruby -v"
      end

      def system_version_command
        "uname -m"
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

      def framework_env_names
        %w[RAILS_ENV RACK_ENV NODE_ENV MERB_ENV]
      end

      def framework_envs
        framework_env_names.map { |e| "#{e}=#{environment}" }.join(' ')
      end

      def set_framework_envs
        framework_env_names.each { |e| ENV[e] = environment }
      end

      def precompile_assets_inferred?
        !precompile_assets? && !skip_precompile_assets?
      end

      def precompile_assets?
        configuration['precompile_assets'] == true
      end

      def skip_precompile_assets?
        configuration['precompile_assets'] == false
      end

      # nil if there is no stack (leaving it to method missing causes NoMethodError)
      def stack
        configuration['stack']
      end

      # Assume downtime required if stack is not specified (nil) just in case.
      def required_downtime_stack?
        [nil, 'nginx_mongrel', 'glassfish'].include? stack
      end

      def enable_maintenance_page_on_restart?
        configuration.fetch('maintenance_on_restart', required_downtime_stack?)
      end

      def enable_maintenance_page_on_migrate?
        configuration.fetch('maintenance_on_migrate', true)
      end

      # Enable if stack requires it or if overridden in the ey.yml config.
      def enable_maintenance_page?
        enable_maintenance_page_on_restart? || (migrate? && enable_maintenance_page_on_migrate?)
      end

      # We disable the maintenance page if we would have enabled.
      def disable_maintenance_page?
        enable_maintenance_page?
      end

      def exclusions
        copy_exclude.map { |e| %|--exclude="#{e}"| }.join(' ')
      end

      def ignore_database_adapter_warning?
        configuration.fetch('ignore_database_adapter_warning', false)
      end

    end
  end
end
