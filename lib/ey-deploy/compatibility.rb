module EY
  class Compatibility
    attr_reader :server_version, :client_version, :server_required

    def initialize(client_version, server_required)
      require 'rubygems'
      @client_version = Gem::Version.new(client_version)
      @server_required = Gem::Requirement.new(server_required)
      @server_version = Gem::Version.new(EY::VERSION)
    end

    def server_required_version
      server_required.requirements.first.last
    end

    def compatible?
      server_required.satisfied_by?(server_version)
    end

    def server_newer?
      server_version > server_required_version
    end
  end
end