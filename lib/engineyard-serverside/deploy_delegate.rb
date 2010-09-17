module EY
  module DeployDelegate
    @@delegate_map ||= {}

    def self.for(deploy)
      infra, stack = deploy.config['infrastructure'], deploy.config['stack']

      if found = [ [infra,stack].join('/'), infra.to_s ].detect { |key| @@delegate_map.has_key?(key) }
        @@delegate_map[found].new(deploy)
      else
        raise "Unable to find suitable delegate for #{infra}/#{stack} options are #{@@delegate_map.keys.join(', ')}"
      end
    end

    def self.register(klass, infra, stack=nil)
      @@delegate_map[[infra, stack].compact.join('/')] = klass
    end

    class Base
      def self.register(*args)
        DeployDelegate.register(self, *args)
      end

      attr_reader :deploy

      def initialize(deploy)
        @deploy = deploy
      end

      def maintenance_page_roles() [] end
      def migrate_roles() [] end

      def restart_roles
        # Implement in subclass, return roles of instances where restart should be run
        raise "#{self.class} has not implemented #restart_roles"
      end

      def restart
        # Implement in subclass, perform necessary actions to restart app instances
        raise "#{self.class} has not implemented #restart"
      end
    end
  end
end

require File.join(File.dirname(__FILE__), 'deploy_delegates', 'app_cloud')
