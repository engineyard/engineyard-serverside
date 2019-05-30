# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'engineyard-serverside/version'

Gem::Specification.new do |s|
  s.name = "engineyard-serverside"
  s.version = EY::Serverside::VERSION
  s.platform = Gem::Platform::RUBY
  s.author = "EY Cloud Team"
  s.email = "cloud@engineyard.com"
  s.homepage = "http://github.com/engineyard/engineyard-serverside"
  s.summary = "A gem that deploys ruby applications on EY Cloud instances"
  s.license = 'MIT'

  s.files = Dir.glob("{bin,lib}/**/*") + %w(LICENSE)
  s.executables = ["engineyard-serverside"]
  s.default_executable = "engineyard-serverside"
  s.require_path = 'lib'

  s.add_development_dependency('rspec', '~>2.14')
  s.add_development_dependency('rake', '~>10.0.0')
  s.add_development_dependency('rdoc', '~>4.2.2')
  s.add_development_dependency('timecop', '0.6.1')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('engineyard-serverside-adapter', '~>2.4.0')
  s.add_development_dependency('sqlite3', '~> 1.3.13')
  s.add_development_dependency('mime-types', '~>1.25')
  s.add_development_dependency('json', '<2')
  s.add_development_dependency('cucumber', '~> 1.3.20')
  s.add_development_dependency('aruba', '~> 0.14.2')

  s.required_rubygems_version = %q{>= 1.3.6}
  s.test_files = Dir.glob("spec/**/*")
end
