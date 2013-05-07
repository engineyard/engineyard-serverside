module EY
  module Serverside
    module CLIHelpers
      def account_app_env_options
        method_option :app,              :type     => :string,
                                         :required => true,
                                         :desc     => "Application to deploy",
                                         :aliases  => %w[-a --app-name]
        method_option :environment_name, :type     => :string,
                                         :required => true,
                                         :desc     => "Environment name"
        method_option :account_name,     :type     => :string,
                                         :required => true,
                                         :desc     => "Account name"
      end

      def framework_env_option
        method_option :framework_env,    :type     => :string,
                                         :required => true,
                                         :desc     => "Ruby web framework environment",
                                         :aliases  => ["-e"]
      end

      def stack_option
        method_option :stack,            :type     => :string,
                                         :desc     => "Web stack (so we can restart it correctly)"
      end


      def config_option
        method_option :config,           :type     => :string,
                                         :desc     => "Additional configuration"
        method_option :deploy_user,      :type     => :string,
                                         :desc     => "Deploy user if different than current"
      end

      def instances_options
        method_option :instances,        :type     => :array,
                                         :desc     => "Hostnames of instances to deploy to, e.g. --instances localhost app1 app2"
        method_option :instance_roles,   :type     => :hash,
                                         :default  => {},
                                         :desc     => "Roles of instances, keyed on hostname, comma-separated. e.g. instance1:app_master,etc instance2:db,memcached ..."
        method_option :instance_names,   :type     => :hash,
                                         :default  => {},
                                         :desc     => "Instance names, keyed on hostname. e.g. instance1:name1 instance2:name2"
      end

      def verbose_option
        method_option :verbose,          :type     => :boolean,
                                         :desc     => "Verbose output",
                                         :aliases  => ["-v"]
      end
    end
  end
end
