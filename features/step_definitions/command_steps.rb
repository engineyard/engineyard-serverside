Then %(the command has an unsuccessful exit status) do
  step %{the exit status should not be 0}
  step %{the exit status should not be 255}
end

Then %(the command suffers a critical failure) do
  step %{the exit status should be 255}
end
