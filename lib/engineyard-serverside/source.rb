require 'pathname'
require 'engineyard-serverside/spawner'

class EY::Serverside::Source
  attr_reader :uri, :opts, :source_cache, :ref, :shell
  alias repository_cache source_cache

  class << self
    attr_reader :required_opts
    def require_opts(*names)
      @required_opts ||= []
      @required_opts += names
    end

    def for(type)
      const_get(type)
    end
  end

  def initialize(shell, opts={})
    @shell = shell
    @opts = opts

    if self.class.required_opts && !self.class.required_opts.all? {|name| @opts[name] }
      raise ArgumentError,
        "Missing required key(s) (#{self.class.required_opts.join(', ')} required)"
    end

    @ref = @opts[:ref]
    @uri = @opts[:uri].to_s if @opts[:uri]
    @source_cache = Pathname.new(@opts[:repository_cache]) if @opts[:repository_cache]
  end

  protected

  def in_source_cache(&block)
    raise ArgumentError, "Block required" unless block
    source_cache.mkpath
    Dir.chdir(source_cache, &block)
  end

  def escape(*shell_commands)
    Escape.shell_command(shell_commands)
  end

  def runner
    EY::Serverside::Spawner
  end

  # Internal: Run a command.
  #
  # cmd - A string command.
  #
  # Returns an instance of Spawner.
  def run(cmd)
    runner.run(cmd, shell, nil)
  end

  # Internal: Run a command and return the output.
  #
  # cmd - A string command.
  #
  # Returns the output of the command.
  def run_and_output(cmd)
    run(cmd).output
  end

  # Internal: Run a command and check if it was successful.
  #
  # cmd - A string command.
  #
  # Returns success.
  def run_and_success?(cmd)
    run(cmd).success?
  end
end
