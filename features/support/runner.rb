require 'runner'
require 'engineyard-serverside/spawner'

module ExecutedCommands
  def self.record(cmd)
    executed.push(cmd)

    EY::Serverside::Spawner::Result.new(cmd, true, nil, nil)
  end

  def self.executed
    @executed ||= []
  end

  def self.reset
    @executed = nil
  end

  def self.deploy_hook_executed?(callback_name)
    executed.
      select {|x|
        x.match(%r{engineyard-serverside-execute-hook #{callback_name}})
      }.length > 0
  end

end

module Runner
  def run(cmd)
    ExecutedCommands.record(cmd)
  end
end
