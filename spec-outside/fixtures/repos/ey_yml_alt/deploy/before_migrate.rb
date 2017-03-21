run "echo '#{config.custom}' > custom_hook"
if config.paths.enabled_maintenance_page.exist?
  run "echo 'maintenance page enabled' > maintenance_enabled"
else
  run "echo 'no maintenance page' > maintenance_disabled"
end
