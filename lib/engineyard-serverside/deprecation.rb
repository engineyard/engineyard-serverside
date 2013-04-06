require 'engineyard-serverside/shell/helpers'

module EY
  module Serverside
    def self.deprecation_warning(msg)
      $stderr.puts "DEPRECATION WARNING: #{msg}\n\t#{caller(2).first}"
    end

    def self.deprecated_task(receiver, old_task, new_task)
      if receiver.respond_to?(old_task)
        deprecation_warning("Task ##{old_task} has been renamed to ##{new_task}.")
      end
    end

    def self.const_missing(const)
      case const
      when :LoggedOutput
        EY::Serverside.deprecation_warning("EY::Serverside::LoggedOutput has been deprecated. Use EY::Serverside::Shell::Helpers instead.")
        EY::Serverside::Shell::Helpers
      when :LockfileParser
        EY::Serverside.deprecation_warning("EY::Serverside::LockfileParser has been deprecated. Use EY::Serverside::DependencyManager::BundlerLock::Lockfile instead.")
        EY::Serverside::DependencyManager::BundlerLock::Lockfile
      else
        super
      end
    end
  end
end
