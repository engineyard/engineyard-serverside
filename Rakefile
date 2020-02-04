require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'cucumber/rake/task'

Cucumber::Rake::Task.new

RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = %w[--color]
  t.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:spec2) do |t|
  t.rspec_opts = %w[--color]
  t.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:php) do |spec|
  t.libs << 'lib' << 'spec'
  t.pattern = 'spec/**/*php*_spec.rb'
end

RSpec::Core::RakeTask.new(:inside) do |t|
  t.rspec_opts = %w[--color]
  t.pattern = 'spec-inside/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:outside) do |t|
  t.rspec_opts = %w[--color]
  t.pattern = 'spec-outside/**/*_spec.rb'
end

desc "Run specs and generate coverage data"
task :coverage => [:coverage_env, :spec]

task :coverage_env do
  ENV['COVERAGE'] = '1'
end

task :inside_spec => [:inside, :spec]
task :outside_spec => [:outside, :spec2]

task :test => [:cucumber, :inside, :outside]
task :default => [:test]

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
