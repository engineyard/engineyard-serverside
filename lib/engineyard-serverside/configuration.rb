require 'multi_json'
require 'thor'
require 'pp'
require 'yaml'
require 'engineyard-serverside/paths'

module EY
  module Serverside
    class Deploy::Configuration
      include Paths::LegacyHelpers # deploy hooks depend on these to be here as well. Don't remove without plenty of deprecation warnings.

      # Defines a fetch method for the specified key.
      # If no default and no block is specified, it means the key is required
      # and if it's accessed without a value, it should raise.
      def self.def_option(name, default=nil, key=nil, &block)
        key ||= name.to_s
        if block_given?
          define_method(name) { fetch(key) {instance_eval(&block)} }
        else
          define_method(name) { fetch(key, default) }
        end
      end

      # Calls def_option and adds a name? predicate method
      def self.def_boolean_option(name, default=nil, &block)
        key ||= name.to_s

        define_method(name) do
          if block
            val = fetch(key) {instance_eval(&block)}
          else
            val = fetch(key, default)
          end
          not [false,nil,'false','nil'].include?(val) # deal with command line options turning booleans into strings
        end
        alias_method(:"#{name}?", name)
      end

      # Required options do not have a default value.
      # An option being required does not mean that it is always supplied,
      # it just means that if it is accessed and it does not exist, an error
      # will be raised instead of returning a nil default value.
      def self.def_required_option(name, key=nil)
        key ||= name.to_s
        define_method(name) do
          fetch(key) { raise "Required configuration option not found: #{key.inspect}" }
        end
      end

      def_required_option :app
      def_required_option :environment_name
      def_required_option :account_name
      def_required_option :framework_env
      def_required_option :instances
      def_required_option :instance_roles
      def_required_option :instance_names

      def_option :repo,              nil
      def_option :migrate,           nil
      def_option :precompile_assets, 'detect'
      def_option :precompile_assets_task, 'assets:precompile'
      def_option :asset_strategy,    'shifting'
      def_option :asset_dependencies, %w[app/assets lib/assets vendor/assets Gemfile.lock config/routes.rb config/application.rb]
      def_option :stack,             nil
      def_option :strategy,          'Git'
      def_option :branch,            'master'
      def_option :current_roles,     []
      def_option :current_name,      nil
      def_option :asset_roles,       [:app_master, :app, :solo]
      def_option :copy_exclude,      []
      def_option :bundle_options,    nil
      def_option(:bundle_without)    { %w[test development] - [framework_env] }
      def_option(:user)              { ENV['USER'] }
      def_option(:group)             { user }
      def_option :services_check_command, "which /usr/local/ey_resin/ruby/bin/ey-services-setup >/dev/null 2>&1"
      def_option(:services_setup_command) { "/usr/local/ey_resin/ruby/bin/ey-services-setup #{app}" }

      def_boolean_option :verbose,                         false
      def_boolean_option :precompile_unchanged_assets,     false
      def_boolean_option :ignore_database_adapter_warning, false
      def_boolean_option :eydeploy_rb,                     true
      def_boolean_option :maintenance_on_migrate,          true
      def_boolean_option(:maintenance_on_restart)          { required_downtime_stack? }

      alias app_name app
      alias environment framework_env # legacy because it would be nice to have less confusion around "environment"
      alias migration_command migrate

      def initialize(options)
        opts = string_keys(options)
        config = MultiJson.load(opts.delete("config") || "{}")
        append_config_source opts # high priority
        append_config_source config # lower priority
      end

      def string_keys(hsh)
        hsh.inject({}) { |h,(k,v)| h[k.to_s] = v; h }
      end

      def append_config_source(config_source)
        @config_sources ||= []
        @config_sources.unshift(config_source.dup)
        reload_configuration!
      end

      def configuration
        @configuration ||= @config_sources.inject({}) {|low,high| low.merge(high)}
      end
      # FIXME: single letter variable is of very questionable value
      alias :c :configuration

      # reset cached configuration hash
      def reload_configuration!
        @configuration = nil
      end

      def load_ey_yml_data(data, shell)
        loaded = false

        environments = data['environments']
        if environments && environments[environment_name]
          shell.substatus "ey.yml configuration loaded for environment #{environment_name.inspect}."

          env_data = string_keys(environments[environment_name])
          shell.debug "#{environment_name}:\n#{env_data.pretty_inspect}"

          append_config_source(env_data) # insert at higher priority than defaults
          loaded = true
        end

        defaults = data['defaults']
        if defaults
          shell.substatus "ey.yml configuration loaded."
          append_config_source(string_keys(defaults)) # insert at lowest priority so as not to disturb important config
          shell.debug "defaults:\n#{defaults.pretty_inspect}"
          loaded = true
        end

        if loaded
          true
        else
          shell.info "No matching ey.yml configuration found for environment #{environment_name.inspect}."
          shell.debug "ey.yml:\n#{data.pretty_inspect}"
          false
        end
      end

      # Fetch a key from the config.
      # You must supply either a default second argument, or a default block
      def fetch(key, *args, &block)
        configuration.fetch(key.to_s, *args, &block)
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

      # Delegate to the configuration objects
      def method_missing(meth, *args, &blk)
        configuration.key?(meth.to_s) ? configuration.fetch(meth.to_s) : super
      end

      def respond_to?(meth, include_private=false)
        configuration.key?(meth.to_s) || super
      end

      def to_json
        MultiJson.dump(configuration)
      end

      def node
        EY::Serverside.node
      end

      # Infer the deploy strategy to use based on flag or default to specified
      # strategy.
      #
      # Returns a strategy class.
      def strategy_class
        EY::Serverside::Strategies.const_get(detect_strategy)
      end

      # Check for which strategy is being used or return the default.
      #
      # Returns a string strategy class name.
      def detect_strategy
        @detected_strategy ||= if git
          "Git"
        elsif archive
          "Archive"
        else
          strategy
        end
      end

      # Get the uri that the strategy should use.
      #
      # Returns a string uri.
      def strategy_uri
        self[detect_strategy.downcase] || self[:repo]
      end

      def paths
        @paths ||= Paths.new({
          :home             => configuration['home_path'],
          :app_name         => app_name,
          :deploy_root      => configuration['deploy_to'],
          :active_release   => configuration['release_path'],
          :repository_cache => configuration['repository_cache'],
        })
      end

      def rollback_paths!
        rollback_paths = paths.rollback
        if rollback_paths
          @paths = rollback_paths
          true
        else
          false
        end
      end

      def ruby_version_command
        "ruby -v"
      end

      def system_version_command
        "uname -m"
      end

      def active_revision
        paths.active_revision.read.strip
      end

      def latest_revision
        paths.latest_revision.read.strip
      end
      alias revision latest_revision

      def previous_revision
        prev = paths.previous_revision
        prev && prev.readable? && prev.read.strip
      end

      # The nodatabase.yml file is dropped by server configuration when there is
      # no database in the cluster.
      def has_database?
        paths.shared_config.join('database.yml').exist? &&
          !paths.shared_config.join('nodatabase.yml').exist?
      end

      def check_database_adapter?
        !ignore_database_adapter_warning? && has_database?
      end

      def migrate?
        !!migration_command
      end

      def role
        node['instance_role']
      end

      def current_role
        current_roles.to_a.first
      end

      def framework_env_names
        %w[RAILS_ENV RACK_ENV NODE_ENV MERB_ENV]
      end

      def framework_envs
        framework_env_names.map { |e| "#{e}=#{framework_env}" }.join(' ')
      end

      def set_framework_envs
        framework_env_names.each { |e| ENV[e] = environment }
      end

      def extra_bundle_install_options
        opts = []
        opts += ["--without", bundle_without] if bundle_without
        opts += [bundle_options] if bundle_options
        opts.flatten
      end

      def precompile_assets_inferred?
        precompile_assets.nil? || precompile_assets == "detect"
      end

      def precompile_assets?
        precompile_assets == true || precompile_assets == "true"
      end

      def skip_precompile_assets?
        precompile_assets == false || precompile_assets == "false"
      end

      # Assume downtime required if stack is not specified (nil) just in case.
      def required_downtime_stack?
        [nil, 'nginx_mongrel', 'glassfish'].include? stack
      end

      def configured_services
        services = YAML.load_file(paths.shared_services_yml.to_s)
        services.respond_to?(:keys) && !services.empty? ? services.keys : nil
      rescue
        nil
      end
    end
  end
end
