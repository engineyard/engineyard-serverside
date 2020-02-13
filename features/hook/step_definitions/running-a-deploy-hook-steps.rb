require 'fileutils'

def account_name
  recall_fact(:account_name)
end

def app_name
  recall_fact(:app_name)
end

def env_name
  recall_fact(:env_name)
end

def framework_env
  recall_fact(:framework_env)
end

def service_name
  recall_fact(:service_name)
end

Given %r{^my account name is (.+)$} do |account_name|
  memorize_fact(:account_name, account_name)
end

Given %r{^my app's name is (.+)$} do |app_name|
  memorize_fact(:app_name, app_name)
  setup_release_path
end

Given %r{^my app lives in an environment named (.+)$} do |env_name|
  memorize_fact(:env_name, env_name)
end

Given %r{^the framework env for my environment is (.+)$} do |framework_env|
  memorize_fact(:framework_env, framework_env)
end

Then %r{^I see output indicating that the (.+) hooks were processed$} do |hook_name|
  expect(output_text).to include(hook_name)
end

Given %{my app has no deploy hooks} do
  cleanup_deploy_hooks_path
  true
end

Given %{my app has no service hooks} do
  cleanup_shared_hooks_path
  true
end

When %r{^I run the (.+) callback$} do |callback_name|
  #puts "Data: '#{Dir["#{data_path}/**/*"]}'"

  config = {:deploy_to => app_path.to_s}

  command = [
    'engineyard-serverside',
    'hook',
    callback_name,
    "--app=#{app_name}",
    "--environment-name=#{env_name}",
    "--account-name=#{account_name}",
    "--framework-env=#{framework_env}",
    "--release-path=#{release_path}",
    "--config='#{config.to_json}'"
  ].join(' ')

  step %(I run `#{command}`)
end

Then %r{^I see a notice that the (.+) callback was skipped$} do |callback_name|
  expect(output_text).to include("#{callback_name}. Skipping.")
end

def write_ruby_deploy_hook(callback_name, content)
  setup_deploy_hooks_path

  hook = deploy_hooks_path.join("#{callback_name}.rb")

  f = File.open(hook.to_s, 'w')
  f.write(content.to_s)
  f.close
end

Given %r{^my app has a (.+) ruby deploy hook$} do |callback_name|
  write_ruby_deploy_hook(callback_name, 'true')
end

Then %r{^the (.+) ruby deploy hook is executed$} do |callback_name|
  expect(output_text).
    to include("Executing #{deploy_hooks_path.join("#{callback_name}.rb")}")
end

Given %r{^my app has a (.+) executable deploy hook$} do |callback_name|
  setup_deploy_hooks_path

  hook = deploy_hooks_path.join(callback_name)
  f = File.open(hook.to_s, 'w')
  f.write("#!/bin/bash\n\necho #{hook.to_s}")
  f.close

  hook.chmod(0755)
end

Then %r{^the (.+) executable deploy hook is executed$} do |callback_name|
  expect(ExecutedCommands.deploy_hook_executed?(callback_name)).to eql(true)
end

Then %r{^the (.+) executable deploy hook is not executed$} do |callback_name|
  expect(ExecutedCommands.deploy_hook_executed?(callback_name)).to eql(false)
end

Given %r{^I have a service named (.+)$} do |service_name|
  memorize_fact(:service_name, service_name)
end

Given %r{^my service has a (.+) ruby hook$} do |callback_name|
  setup_service_path(service_name)

  hook = service_path(service_name).join("#{callback_name}.rb")

  f = File.open(hook.to_s, 'w')
  f.write('true')
  f.close
end

Then %r{^the (.+) ruby hook for my service is executed$} do |callback_name|
  hook = service_path(service_name).join("#{callback_name}.rb")

  expect(output_text).to include("Executing #{hook}")
end

Given %r{^my service has a (.+) executable hook$} do |callback_name|
  setup_service_path(service_name)

  hook = service_path(service_name).join(callback_name)
  f = File.open(hook.to_s, 'w')
  f.write("#!/bin/bash\n\necho #{hook.to_s}")
  f.close

  hook.chmod(0755)
end

Then %r{^the (.+) executable hook for my service is executed$} do |callback_name|
  expect(ExecutedCommands.service_hook_executed?(service_name, callback_name)).
    to eql(true)
end

Then %r{^the (.+) executable hook for my service is not executed$} do |callback_name|
  expect(ExecutedCommands.service_hook_executed?(service_name, callback_name)).
    to eql(false)
end

Given %r{^my app's (.+) executable deploy hook is not actually executable$} do |callback_name|
  hook = deploy_hooks_path.join(callback_name)

  hook.chmod(0644)
end

Given %r{^my app's (.+) ruby deploy hook contains syntax errors$} do |callback_name|
  write_ruby_deploy_hook(callback_name, "# encoding: UTF-8\n\n)")
end

Then %r{^I see a notice about the (.+) syntax error$} do |callback_name|
  hook = deploy_hooks_path.join("#{callback_name}.rb")
  expect(output_text).to include("*** [Error] Invalid Ruby syntax in hook: #{hook}")
end

Then %r{^the (.+) ruby deploy hook is not executed$} do |callback_name|
  expect(output_text).
    not_to include("Executing #{deploy_hooks_path.join("#{callback_name}.rb")}")
end

Then %{I see the output} do
  puts "OUTPUT START\n\n#{output_text}\n\nOUTPUT END"
end
