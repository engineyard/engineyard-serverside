module OutputHelpers
  def output_text
    last_command_started.output
  end
end

World(OutputHelpers)
