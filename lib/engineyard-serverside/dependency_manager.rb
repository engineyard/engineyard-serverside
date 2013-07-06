require 'engineyard-serverside/dependency_manager/bundler'
require 'engineyard-serverside/dependency_manager/npm'
require 'engineyard-serverside/dependency_manager/composer'

module EY
  module Serverside
    # DependencyManager encapsulates any number of dependency manager objects.
    #
    # If a dependency manager indicates that it has detected the required
    # file or state in order to run, it will be included in this set.
    #
    # Methods called on an instance of DependencyManager are forwarded to
    # any or all of the detected dependency managers.
    #
    # Some actions, like check and install, are forwarded to all of the
    # dependency managers. Other methods will take the first dependency manager
    # that returns a value.
    #
    class DependencyManager
      # Registry pattern be damned. Hard code it and fix it when we want to
      # support dynamic loading. Right now we have no way to load dependency
      # managers dynamically, so why support it?
      AVAILABLE_MANAGERS = [Bundler, Composer, Npm]

      include Enumerable

      # Initialize detected dependency managers
      def initialize(*args)
        @detected = AVAILABLE_MANAGERS.map { |klass| klass.new(*args) }.select { |manager| manager.detected? }
      end

      def each(&block)
        @detected.each(&block)
      end

      def to_a
        @detected
      end

      # Did we find any dependency managers?
      def detected?
        any?
      end

      # Verify application state with respect to dependency management.
      # Warn if there is anything wrong with the dependency manager.
      def check
        each { |m| m.check }
      end

      # Install dependencies for each of the dependency managers.
      def install
        each { |m| m.install }
      end

      # Assume application is not using sqlite3 unless a dependency manager
      # says that sqlite is loaded and likely to be the only manager.
      #
      # This may have problems in the future if one manager detects sqlite
      # but another has the primary database manager.
      #
      # Hopefully this method can be removed in the future and sqlite loading
      # can be done without interfering with other systems.
      def uses_sqlite3?
        any? { |m| m.respond_to?(:uses_sqlite3?) && m.uses_sqlite3? }
      end

      # Use the response from the first dependency manager that returns
      # a rails version.
      def rails_version
        version = nil
        find { |m| version = m.respond_to?(:rails_version) && m.rails_version }
        version
      end

      # If services are installed, print intructions for using ey_config if
      # the dependency manager has a compatible version.
      def show_ey_config_instructions
        each { |m| m.respond_to?(:show_ey_config_instructions) && m.show_ey_config_instructions }
      end
    end
  end
end
