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

Given %r{^my account name is (.+)$} do |account_name|
  memorize_fact(:account_name, account_name)
end

Given %r{^my app's name is (.+)$} do |app_name|
  memorize_fact(:app_name, app_name)
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
  step %(I run `engineyard-serverside hook #{callback_name} --app=#{app_name} --environment-name=#{env_name} --account-name=#{account_name} --framework-env=#{framework_env} --release-path=#{release_path}`)
end

Then %r{^I see a notice that the (.+) callback was skipped$} do |callback_name|
  expect(output_text).to include("#{callback_name}. Skipping.")
end

Given %r{^my app has a (.+) ruby deploy hook$} do |callback_name|
  setup_deploy_hooks_path
  FileUtils.touch(deploy_hooks_path.join("#{callback_name}.rb"))
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
  found = ExecutedCommands.
    executed.
    select {|x|
      x.match(/engineyard-serverside-execute-hook #{callback_name}/)
    }.length > 0

    expect(found).to eql(true)
end

Then %{I see the output} do
  puts "OUTPUT START\n\n#{output_text}\n\nOUTPUT END"
end
