require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end
task :default => :spec

require 'rake/rdoctask'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'ey-deploy'

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

task :bump do
  version_file = "module EY\n  VERSION = '_VERSION_GOES_HERE_'\nend\n"

  new_version = if EY::VERSION =~ /\.pre$/
                  EY::VERSION.gsub(/\.pre$/, '')
                else
                  digits = EY::VERSION.scan(/(\d+)/).map { |x| x.first.to_i }
                  digits[-1] += 1
                  digits.join('.') + ".pre"
                end

  puts "New version is #{new_version}"
  File.open('lib/ey-deploy/version.rb', 'w') do |f|
    f.write version_file.gsub(/_VERSION_GOES_HERE_/, new_version)
  end

end
