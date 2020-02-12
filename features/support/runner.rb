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

  def self.hook_executed?(path)
    executed.select {|x| x.match(/#{Regexp.escape(path)}/)}.length > 0
  end
end

module Runner
  def run(cmd)
    ExecutedCommands.record(cmd)
  end
end
