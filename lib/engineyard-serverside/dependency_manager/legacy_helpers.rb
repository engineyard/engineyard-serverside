module EY
  module Serverside
    class DependencyManager
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
            raise "The method '#{meth}' has been removed to better support future dependency management systems.\nAlthough using these methods directly is discouraged, please see the DependencyManager class and related subclasses if you need access to this information."
          end
        end
      end
    end
  end
end
