require 'engineyard-serverside/spawner/pool'

module EY
  module Serverside

    # Spawner handles the parallel execution and tracking of external
    # shell commands
    module Spawner
      def self.run(command, shell, server = nil)
        Pool.run(command, shell, server)
      end

      def self.pool
        Pool.new
      end
    end
  end
end
