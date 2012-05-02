run "echo '#{config.custom}' > custom_hook"
if File.exist?(config.maintenance_page_enabled_path)
  run "echo 'maintenance page enabled' > maintenance_enabled"
else
  run "echo 'no maintenance page' > maintenance_disabled"
end
