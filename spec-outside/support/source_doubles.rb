class ShellDouble
  attr_reader :messages
  def initialize
    @messages = []
  end

  def status(message)
    @messages << message
  end
end

class RunnerDouble
  def self.run(cmd, shell, server=nil)
    new(cmd)
  end

  def initialize(cmd)
    @cmd = cmd
  end

  def output
    @cmd
  end

  def success?
    true
  end
end
