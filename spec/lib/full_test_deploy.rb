class FullTestDeploy < EY::Serverside::Deploy
  attr_reader :infos, :debugs, :commands

  def initialize(*)
    super
    @infos = []
    @debugs = []
    @commands = []
  end

  # stfu
  def info(msg)
    @infos << msg
  end

  # no really, stfu
  def debug(msg)
    @debugs << msg
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

  def restart
    FileUtils.touch("#{c.release_path}/restart")
  end

  # we're probably running this spec under bundler, but a real
  # deploy does not
  def bundle
    my_env = ENV.to_hash

    ENV.delete("BUNDLE_GEMFILE")
    ENV.delete("BUNDLE_BIN_PATH")

    result = super

    ENV.replace(my_env)
    result
  end

  # we're probably running this spec under bundler, but a real
  # deploy does not
  def gems_include?(*gems)
    my_env = ENV.to_hash

    ENV.delete("BUNDLE_GEMFILE")
    ENV.delete("BUNDLE_BIN_PATH")

    result = super

    ENV.replace(my_env)
    result
  end

  def get_bundler_installer(lockfile, options = '')
    super(lockfile, ' --quiet')
  end

  def bundler_10_installer(version, options = '')
    options << ' --quiet' unless options.include?('--quiet')
    super(version, options)
  end

end
