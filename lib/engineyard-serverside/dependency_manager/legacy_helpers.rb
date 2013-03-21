module EY
  module Serverside
    module DependencyManager
      module LegacyHelpers
        [
          :gemfile?,
          :bundler_config,
          :lockfile,
          :check_ruby_bundler,
          :clean_bundle_on_system_version_change,
          :write_system_version,
          :check_node_npm,
          :clean_environment,
        ].each do |meth|
          define_method(meth) do |*a|
            if dependency_manager.respond_to?(meth)
              dependency_manager.send(meth)
            end
          end
        end
      end
    end
  end
end
