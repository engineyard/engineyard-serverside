class FullTestDeploy < EY::Serverside::Deploy
  attr_reader :commands

  class << self
    attr_accessor :on_create_callback
  end

  def self.realnew(servers, config, shell)
    on_create_callback.call(config) if on_create_callback # holy hax batman, this is insanity
    super
  end

  def initialize(*)
    super
    @commands = []
  end

  # passwordless sudo is neither guaranteed nor desired
  def sudo(cmd)
    run(cmd)
  end

  def run(cmd)
    @commands << cmd
    super
  end

  def restart_command
    Escape.shell_command(["echo", super]) + "> #{config.paths.active_release}/restart"
  end

  # we're probably running this spec under bundler, but a real
  # deploy does not
  def bundle
    my_env = ENV.to_hash
    super
  ensure
    ENV.replace(my_env)
  end

end

class EY::Serverside::Deploy
  class << self
    alias_method :realnew, :new
    attr_reader :config, :deployer
  end
  def self.new(servers, cfg, shell)
    @config = cfg
    @deployer = FullTestDeploy.realnew(servers, cfg, shell)
  end
end

class EY::Serverside::Strategies::IntegrationSpec
  attr_reader :shell, :source_repo, :repository_cache

  def initialize(shell, opts)
    @shell = shell
    @ref = opts[:ref]
    @source_repo = Pathname.new(opts[:uri])
    @repository_cache = Pathname.new(opts[:repository_cache])
  end

  def update_repository_cache
    shell.status "Checking out #{@ref}"
    install_git_base
    copy_fixture_repo_files
  end

  def create_revision_file_command(dir)
    "echo '#{@ref}' > #{dir}/REVISION"
  end

  def short_log_message(revision)
    "ref: #{revision} - Short log message"
  end

  def gc_repository_cache
    shell.status "Garbage collecting cached git repository to reduce disk usage."
  end

  def same?(prev, active, path)
    prev == active # for our tests, being the same commit is sufficient
  end

  private

  def install_git_base
    repository_cache.mkpath
    git_base = FIXTURES_DIR.join('gitrepo.tar.gz')
    shell.substatus "Test helpers copying base repo into #{repository_cache}"
    shell.logged_system "tar xzf #{git_base} --strip-components 1 -C #{repository_cache}"
  end

  def copy_fixture_repo_files
    if source_repo.exist?
      shell.substatus "Test helpers copying repo fixture from #{source_repo}/ to #{repository_cache}"
      # This uses a ruby method instead of shelling out because I was having
      # trouble getting cp -R to behave consistently between distros.
      system "rsync -aq #{source_repo}/ #{repository_cache}"
    else
      raise "Mock repo #{source_repo.inspect} does not exist. Path should be absolute. e.g. FIXTURES_DIR.join('repos','example')"
    end
  end
end
