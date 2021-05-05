Before('@error') do
  memorize_fact(:exit_status, 1)
end

Before('@failure') do
  memorize_fact(:exit_status, 255)
end

After do
  exit_status = begin
                  recall_fact(:exit_status)
                rescue
                  0
                end

  step %{the exit status should be #{exit_status}}
end
