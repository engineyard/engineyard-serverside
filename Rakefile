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
  abort "Failed to build gem; aborting!" unless gem
  system("scp #{gem} #{instance}:")
  system("ssh #{instance} 'sudo /usr/local/ey_resin/ruby/bin/gem install ~/#{gem} --no-rdoc --no-ri'")
end

def bump
  version_file = "module EY\n  VERSION = '_VERSION_GOES_HERE_'\nend\n"

  new_version = if EY::VERSION =~ /\.pre$/
                  EY::VERSION.gsub(/\.pre$/, '')
                else
                  digits = EY::VERSION.scan(/(\d+)/).map { |x| x.first.to_i }
                  digits[-1] += 1
                  digits.join('.') + ".pre"
                end

  File.open('lib/ey-deploy/version.rb', 'w') do |f|
    f.write version_file.gsub(/_VERSION_GOES_HERE_/, new_version)
  end
  new_version
end

desc "Bump version of this gem"
task :bump do
  ver = bump
  puts "New version is #{ver}"
end

desc "Release gem"
task :release do
  new_version = bump
  system("git add lib/ey-deploy/version.rb")
  system("git commit -m 'Bump version for release #{new_version}'")
  system("git tag v#{new_version}")

  system("gem build ey-deploy.gemspec")

  load 'lib/ey-deploy/version.rb'
  bump
  system("git add lib/ey-deploy/version.rb")
  system("git commit -m 'Add .pre for next release'")

  puts '********************************************************************************'
  puts
  puts "Don't forget to `gem push` and `git push --tags`!"
  puts
  puts '********************************************************************************'
end
