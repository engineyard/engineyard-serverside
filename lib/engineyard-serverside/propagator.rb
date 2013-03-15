require 'engineyard-serverside/about'

module EY
  module Serverside
    # Put the same engineyard-serverside on all the servers
    class Propagator
      def self.call(*args)
        new(*args).call
      end

      attr_reader :shell

      def initialize(servers, internal_key_path, shell, options={})
        @remote_servers = servers.remote
        @internal_key_path = internal_key_path
        @shell = shell
      end

      # servers that need to have the gem installed
      def servers
        @servers ||= find_servers_missing_gem
      end

      # Find the servers that need the gem, then install the gem on them
      def call
        servers.any? && propagate
      end

      def remote_gem_file
        File.join(Dir.tmpdir, About.gem_filename)
      end

      def gem_binary
        File.join(Gem.default_bindir, 'gem')
      end

      # the [,)] is to stop us from looking for e.g. 0.5.1, seeing
      # 0.5.11, and mistakenly thinking 0.5.1 is there
      def check_command
        %{#{gem_binary} list #{About.gem_name} | grep "#{About.gem_name}" | egrep -q "#{About.version.gsub(/\./, '\.')}[,)]"}
      end

      def scp_command(server)
        Escape.shell_command([
          'scp',
          '-i', internal_key_path.to_s,
          "-o", "StrictHostKeyChecking=no",
          About.gem_file,
         "#{server.authority}:#{remote_gem_file}",
        ])
      end

      def install_command
        "#{gem_binary} install --no-rdoc --no-ri '#{remote_gem_file}'"
      end

      def count_servers(set)
        "#{set.size} server#{set.size == 1 ? '' : 's'}"
      end

      def find_servers_missing_gem
        return @remote_servers if @remote_servers.empty?
        shell.status "Verifying #{About.name_with_version} on #{count_servers(@remote_servers)}."
        results = @remote_servers.run_on_each(shell, check_command)
        Servers.new results.reject { |result| result.success? }.map { |result| result.server }
      end

      def propagate
        shell.status "Propagating #{About.name_with_version} to #{count_servers(servers)}."
        servers.run_for_each!(shell) { |server| scp_command(server) }
        servers.sudo_on_each(install_command)
      end
    end
  end
end
