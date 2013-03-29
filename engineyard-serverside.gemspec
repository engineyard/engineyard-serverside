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

  s.files = Dir.glob("{bin,lib}/**/*") + %w(LICENSE)
  s.executables = ["engineyard-serverside"]
  s.default_executable = "engineyard-serverside"
  s.require_path = 'lib'

  s.add_development_dependency('rspec', '1.3.2')
  s.add_development_dependency('rake', '>=0.9.2.2', '<10.0')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('timecop')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('engineyard-cloud-client', '~>1.0.11')
  s.add_development_dependency('engineyard-serverside-adapter', '~>2.0.6')
  s.add_development_dependency('sqlite3')

  s.required_rubygems_version = %q{>= 1.3.6}
  s.test_files = Dir.glob("spec/**/*")
end
