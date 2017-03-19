unless RUBY_VERSION =~ /^1\.8\./
  require 'simplecov'
  SimpleCov.coverage_dir 'coverage/inside'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/mock/'
    add_filter '/lib/vendor/'
  end
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'lord'
require 'lord/app'
