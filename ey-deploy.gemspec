lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'bundler'
require 'ey-deploy'

Gem::Specification.new do |s|
  s.name = "ey-deploy"
  s.version = EY::VERSION
  s.platform = Gem::Platform::RUBY
  s.author = "EY Cloud Team"
  s.email = "cloud@engineyard.com"
  s.homepage = "http://engineyard.com"
  s.summary = "A gem that deploys ruby applications on EY Cloud instances"

  s.files = Dir.glob("{bin,lib}/**/*") + %w(LICENSE)
  s.executables = ["ey-deploy"]
  s.default_executable = "ey-deploy"
  s.require_path = 'lib'

  s.rubygems_version = %q{1.3.6}
  s.test_files = Dir.glob("spec/**/*")
end
