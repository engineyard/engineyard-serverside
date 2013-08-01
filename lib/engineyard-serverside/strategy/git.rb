# Deploy strategy for git repository source based deploy.
class EY::Serverside::Strategy::Git < EY::Serverside::Strategy
  require_opts :uri, :ref, :repository_cache

  def create_revision_file_command(revision_file_path)
    %Q{#{git} show --pretty=format:"%H" | head -1 > "#{revision_file_path}"}
  end

  def gc_repository_cache
    shell.status "Garbage collecting cached git repository to reduce disk usage."
    run("#{git} gc")
  end

  # Check if there have been changes.
  # git diff --exit-code returns
  # - 0 when nothing has changed
  # - 1 when there are changes
  #
  # previous_revision - The previous ref string.
  # active_revision - The current ref string.
  #
  #
  # Returns a boolean whether there has been a change.
  def same?(previous_revision, active_revision, paths=nil)
    run_and_success?("#{git} diff '#{previous_revision}'..'#{active_revision}' --exit-code --name-only -- #{Array(paths).join(' ')} >/dev/null 2>&1")
  end

  # Get most recent commit message for revision.
  def short_log_message(revision)
    run_and_output("#{git} log --pretty=oneline --abbrev-commit -n 1 '#{revision}'").strip
  end

  def update_repository_cache
    unless fetch && checkout
      abort "*** [Error] Git could not checkout (#{to_checkout}) ***"
    end
  end

  protected

  # Internal:
  # Returns .
  def checkout
    shell.status "Deploying revision #{short_log_message(to_checkout)}"
    q = opts[:verbose] ? '' : '-q'
    in_source_cache do
      (run_and_success?("git checkout -f #{q} '#{to_checkout}'") ||
        run_and_success?("git reset --hard #{q} '#{to_checkout}'")) &&
        run_and_success?("git submodule sync") &&
        run_and_success?("git submodule update --init") &&
        run_and_success?("git clean -dfq")
    end
  end

  # Internal:
  #
  # Returns .
  def clean_local_branch
    run_and_success?("#{git} show-branch #{ref} > /dev/null 2>&1 && #{git} branch -D #{ref} > /dev/null 2>&1")
  end

  # Internal:
  def fetch
    if usable_repository?
      run_and_success?("#{git} fetch -q origin 2>&1")
    else
      run_and_success?("rm -rf #{repository_cache} && git clone -q #{uri} #{repository_cache} 2>&1")
    end
  end

  def git
    @git ||= "git --git-dir #{repository_cache}/.git --work-tree #{repository_cache}"
  end

  # Internal: Check for valid git repository.
  #
  # Returns a boolean.
  def usable_repository?
    repository_cache.directory? &&
      run_and_output("#{git} remote -v | grep origin").include?(uri)
  end

  # Internal: .
  #
  # Returns .
  def to_checkout
    @to_checkout ||= begin
      clean_local_branch
      remote_branch? ? "origin/#{ref}" : ref
    end
  end

  def remote_branch?
    run_and_success?("#{git} show-branch origin/#{ref} > /dev/null 2>&1")
  end

end
