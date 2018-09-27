require 'engineyard-serverside/spawner'

module Runner
  def runner
    EY::Serverside::Spawner
  end

  # Internal: Run a command.
  #
  # cmd - A string command.
  #
  # Returns an instance of Spawner.
  def run(cmd)
    runner.run(cmd, shell, nil)
  end

  # Internal: Run a command and return the output.
  #
  # cmd - A string command.
  #
  # Returns the output of the command.
  def run_and_output(cmd)
    run(cmd).output
  end

  # Internal: Run a command and check if it was successful.
  #
  # cmd - A string command.
  #
  # Returns success.
  def run_and_success?(cmd)
    run(cmd).success?
  end
end
