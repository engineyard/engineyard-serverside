require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end
task :default => :spec

require 'rake/rdoctask'
require File.expand_path("../lib/ey-deploy", __FILE__)
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ey-deploy #{EY::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/vendor/**/*.rb')
end

desc "Build the gem + install it on the instance: rake install_on[[user@]host]"
task :install_on, [:instance] do |t, args|
  instance = args.instance

  system("gem build ey-deploy.gemspec")
  gem = Dir["*.gem"].last   # hopefully true
  system("scp #{gem} #{instance}:")
  system("ssh #{instance} 'sudo /usr/local/ey_resin/ruby/bin/gem uninstall -a -x ey-deploy; sudo /usr/local/ey_resin/ruby/bin/gem install ~/#{gem}'")
end
