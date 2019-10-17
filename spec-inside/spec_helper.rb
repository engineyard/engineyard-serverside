unless RUBY_VERSION =~ /^1\.8\./
  require 'simplecov'
  SimpleCov.coverage_dir 'coverage/inside'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/mock/'
    add_filter '/lib/vendor/'
    add_group 'CLI Workflows', 'lib/engineyard-serverside/cli/workflows/'
    add_group 'Callbacks', 'lib/engineyard-serverside/callbacks/'
  end
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'engineyard-serverside'
