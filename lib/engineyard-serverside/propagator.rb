require 'forwardable'
require 'engineyard-serverside/about'

module EY
  module Serverside

    # Propagator ensures that a proper version of the engineyard-serverside
    # gem is installed on a given set of servers
    class Propagator
      def self.propagate(servers, shell)
        new(servers, shell).propagate
      end

      extend Forwardable

      def_delegators About, :gem_binary, :gem_file, :gem_filename, :gem_name,
        :name_with_version, :version

      attr_reader :servers, :shell

      def initialize(servers, shell)
        @servers = servers
        @shell = shell
      end

      def propagate
        shell.status "Verifying and propagating #{name_with_version} to all servers."

        servers.remote.run_for_each! do |server|
          propagation_command_for(server)
        end
      end

      private
      def propagation_command_for(server)
        check = server.command_on_server('sh -l -c', check_command)
        scp = server.scp_command(About.gem_file, remote_gem_file)
        install = server.command_on_server('sudo sh -l -c', install_command)

        "(#{check}) || ((#{scp}) && (#{install}))"
      end

      def remote_gem_file
        @remote_gem_file ||= File.join(Dir.tmpdir, gem_filename)
      end

      def check_command
        # the [,)] is to stop us from looking for e.g. 0.5.1, seeing
        # 0.5.11, and mistakenly thinking 0.5.1 is there

         %{#{gem_binary} list #{gem_name} | grep "#{gem_name}" | egrep -q "#{version.gsub(/\./, '\.')}[,)]"}
      end

      def install_command
        "#{gem_binary} install '#{remote_gem_file}'"
      end
    end
  end
end
