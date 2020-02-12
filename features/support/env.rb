unless RUBY_VERSION =~ /^1\.8\./
  require 'simplecov'
  SimpleCov.coverage_dir 'coverage/outside'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/mock/'
    add_filter '/lib/vendor/'
    add_group 'CLI Workflows', 'lib/engineyard-serverside/cli/workflows/'
    add_group 'Callbacks', 'lib/engineyard-serverside/callbacks/'
  end
end

require 'cucumber/rspec/doubles'
require 'aruba/cucumber'
require 'factis/cucumber'
require 'devnull'
require 'engineyard-serverside'

# This is a fun bit of glue to allow us to use Aruba's in-process runner
class Runatron
  include RSpec::Mocks::ExampleMethods

  def initialize(argv, stdin = STDIN, stdout = STDOUT, stderr = STDERR, kernel = Kernel)
    @argv, @stdin, @stdout, @stderr, @kernel = argv, stdin, stdout, stderr, kernel
  end

  def execute!
    exit_code = begin
                  $stderr = @stderr
                  $stdin = @stdin
                  $stdout = @stdout
                  $logger = Logger.new(DevNull.new)
                  allow(Logger).to receive(:new).and_return($logger)

                  EY::Serverside::CLI::App.start(@argv)
                rescue StandardError => e
                  b = e.backtrace
                  @stderr.puts("#{b.shift}: #{e.message} (#{e.class})")
                  @stderr.puts(b.map {|s| "\tfrom #{s}"}.join("\n"))
                rescue SystemExit => e
                  e.status
                ensure
                  $stderr = STDERR
                  $stdin = STDIN
                  $stdout = STDOUT
                end

    @kernel.exit(exit_code)
  end
end

Aruba.configure do |config|
  config.command_launcher = :in_process
  config.main_class = Runatron
end

After do
  ExecutedCommands.reset
  cleanup_fs
end
