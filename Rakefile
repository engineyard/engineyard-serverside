require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = %w[--color]
  t.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:php) do |spec|
  t.libs << 'lib' << 'spec'
  t.pattern = 'spec/**/*php*_spec.rb'
end

task :coverage => [:coverage_env, :spec]

task :coverage_env do
  ENV['COVERAGE'] = '1'
end

task :test => :spec
task :default => :spec

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'engineyard-serverside'
require 'engineyard-serverside/version'

begin
  require 'rdoc/task'
  rdoc_task = RDoc::Task
rescue LoadError => ex
  require 'rake/rdoctask' # older than RDoc 2.4.2
  rdoc_task = Rake::RDocTask
end

rdoc_task.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "engineyard-serverside #{EY::Serverside::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/vendor/**/*.rb')
end

desc "Build the gem + install it on the app master of the environment: rake install_on[(account/)environment]"
task :install_on, [:environment] do |t, args|
  require 'engineyard-cloud-client'

  account_name, environment_name = if args.environment =~ /\//
                                     args.environment.split('/')
                                   else
                                     ['', args.environment]
                                   end

  unless `gem build engineyard-serverside.gemspec 2>&1` =~ /File: (engineyard-serverside-.*\.gem)/
    abort "Failed to build gem; aborting!"
  end

  gemname = $1

  require 'yaml'
  # hacky loading with no error checking
  api_token = YAML.load_file("#{ENV['HOME']}/.eyrc")['api_token'] if File.exist?("#{ENV['HOME']}/.eyrc")
  unless api_token
    raise "Couldn't find api_token in ~/.eyrc. Use engineyard gem to login."
  end

  client = EY::CloudClient.new(:token => api_token)
  result = client.resolve_environments({
    :account_name     => account_name,
    :environment_name => environment_name,
  })

  result.one_match do |env|
    puts "Environment found: #{env.account.name}/#{env.name}"
    env.deploy_to_instances.each do |instance|
      user_host = "#{env.username}@#{instance.hostname}"
      puts "Installing #{gemname} to #{instance.hostname}"
      system("scp -o CheckHostIP=no -o StrictHostKeyChecking=no #{gemname} #{user_host}: ")
      system("ssh -o CheckHostIP=no -o StrictHostKeyChecking=no #{user_host} 'sudo /usr/local/ey_resin/ruby/bin/gem install ~/#{gemname} --no-rdoc --no-ri'")
    end
  end
end

def bump
  new_version = if EY::Serverside::VERSION =~ /\.pre$/
                  EY::Serverside::VERSION.gsub(/\.pre$/, '')
                else
                  digits = EY::Serverside::VERSION.scan(/(\d+)/).map { |x| x.first.to_i }
                  digits[-1] += 1
                  digits.join('.') + ".pre"
                end

  version_file = <<-EOV
module EY
  module Serverside
    VERSION = '#{new_version}'
  end
end
  EOV

  File.open('lib/engineyard-serverside/version.rb', 'w') do |f|
    f.write version_file
  end
  new_version
end

def run_commands(*cmds)
  cmds.flatten.each do |c|
    system(c) or raise "Command "#{c}" failed to execute; aborting!"
  end
end

def release_changelog(version)
  clog = Pathname.new('ChangeLog.md')
  new_clog = clog.read.sub(/^## NEXT$/, <<-SUB.chomp)
## NEXT

  *

## v#{version} (#{Date.today})
  SUB
  clog.open('w') { |f| f.puts new_clog }
end

desc "Bump version of this gem"
task :bump do
  ver = bump
  puts "New version is #{ver}"
end

desc "Release gem"
task :release do
  new_version = bump
  release_changelog(new_version)
  run_commands(
    "git add ChangeLog.md lib/engineyard-serverside/version.rb",
    "git commit -m 'Bump version for release #{new_version}'",
    "gem build engineyard-serverside.gemspec")

  #will raise a warning, but needed to load the new version after the last call to 'bump'
  load 'lib/engineyard-serverside/version.rb'
  bump

  run_commands(
    "git add lib/engineyard-serverside/version.rb",
    "git commit -m 'Add .pre for next release'",
    "git tag v#{new_version} HEAD^")

  puts <<-PUSHGEM
## To publish the gem: #########################################################

    gem push engineyard-serverside-#{new_version}.gem
    git push origin master v#{new_version}

## No public changes yet. ######################################################
  PUSHGEM
end
