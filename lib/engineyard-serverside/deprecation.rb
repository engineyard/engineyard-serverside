require 'engineyard-serverside/shell/helpers'
require 'engineyard-serverside/dependency_manager/bundler'
require 'engineyard-serverside/source/git'

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

    DEPRECATED_CLASSES = {
      :LoggedOutput   => EY::Serverside::Shell::Helpers,
      :LockfileParser => EY::Serverside::DependencyManager::Bundler::Lockfile,
      :Strategies     => EY::Serverside::Source::Git
    }
    def self.const_missing(const)
      if klass = DEPRECATED_CLASSES[const]
        deprecation_warning("EY::Serverside::#{const} has been deprecated. Please use: #{klass}")
        klass
      else
        super
      end
    end
  end
end
