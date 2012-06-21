class FullTestDeploy < EY::Serverside::Deploy
  attr_reader :commands

  def initialize(*)
    super
    @commands = []
    @gemfile_contents = nil
    @lockfile_contents = nil
  end

  # passwordless sudo is neither guaranteed nor desired
  def sudo(cmd)
    run(cmd)
  end

  def run(cmd)
    @commands << cmd
    super
  end

  def version_specifier
    # Normally, the deploy task invokes the hook task by executing
    # the rubygems-generated wrapper (it's what's in $PATH). It
    # specifies the version to make sure that the pieces don't get
    # out of sync. However, in test mode, there's no
    # rubygems-generated wrapper, and so the hook task doesn't get
    # run because thor thinks we're trying to invoke the _$VERSION_
    # task instead, which doesn't exist.
    #
    # By stripping that out, we can get the hooks to actually run
    # inside this test.
    nil
  end

  def restart_command
    Escape.shell_command(["echo", super]) + "> #{config.paths.active_release}/restart"
  end

  # we're probably running this spec under bundler, but a real
  # deploy does not
  def bundle
    my_env = ENV.to_hash

    if defined?(Bundler)
      Bundler.with_clean_env do
        result = super
      end
    else
      result = super
    end

    ENV.replace(my_env)
    result
  end

  def framework_env
    config.framework_env
  end

  def services_command_check
    @mock_services_command_check || "which echo"
  end

  def mock_services_command_check!(value)
    @mock_services_command_check = value
  end

  def services_setup_command
    @mock_services_setup_command || "echo 'services setup command'"
  end

  def mock_services_setup!(value)
    @mock_services_setup_command = value
  end
end

class EY::Serverside::Strategies::IntegrationSpec
  attr_reader :shell, :source_repo, :repository_cache

  def initialize(shell, opts)
    unless opts[:repository_cache] && opts[:repo]
      raise ArgumentError, "Option :repository_cache and :repo are required"
    end

    @shell = shell
    @ref = opts[:ref]
    @source_repo = Pathname.new(opts[:repo])
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
      FileUtils.cp_r Dir.glob("#{source_repo}/*"), repository_cache
    else
      raise "Mock repo #{source_repo.inspect} does not exist. Path should be absolute. e.g. FIXTURES_DIR.join('repos','example')"
    end
  end
end
