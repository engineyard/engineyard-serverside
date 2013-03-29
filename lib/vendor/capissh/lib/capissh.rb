# NOTES
#
# Parts
#
# * Server definition - Some object that can be executed on to connect to a server
# * Server collection - A collection of servers on which to execute
# * Command - What to run on the servers
# * CommandTree - What to run in parallel
#
# SSH Related stuff
# * Connection - A connection to a server definition that is held for reuse
# * Connection pool - All the connections so persistent connections can be found
# * Connection factory - Creates a persistent connection from a server definition
#
# Set of servers
# Command
# Run this command on this set of servers...
# Using this connector (or the default ssh connector)
#
# State to be kept somewhere:
#   servers with sessions
# * set of sessions (if sessions are being persisted, with max hosts set, this could be a subset that gets blown away)
# * set of servers, connected to sessions (this needs to be filterable by the user)
#   these are both 1 to 1
#   need to sort, constrain, etc
# * Capissh init options
#
#
# connector receives a server (set of servers?) and a command (command tree?)
#   functionality: to interogate servers and figure out which command should
#   run on each server and then hand out the command to the appropriate server.
#   connector steps through servers (or command tree) and yields the command to each server
# Yielding expects each server to run the command given (or maybe it just has the
# chance to modify the command?)
#

require 'capissh/configuration'

module Capissh
  def self.new(*args)
    Capissh::Configuration.new(*args)
  end
end
