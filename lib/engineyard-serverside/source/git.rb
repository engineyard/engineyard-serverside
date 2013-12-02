require 'engineyard-serverside/source'

# Deploy source for git repository sourced deploy.
class EY::Serverside::Source::Git < EY::Serverside::Source
  require_opts :ref, :repository_cache

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
      shell.fatal "git checkout #{to_checkout} failed."
      raise "git checkout #{to_checkout} failed."
    end
  end

  protected

  # Internal:
  # Returns .
  def checkout
    shell.status "Deploying revision #{short_log_message(to_checkout)}"
    in_source_cache do
      (run_and_success?("git checkout --force #{quiet} '#{to_checkout}'") ||
        run_and_success?("git reset --hard #{quiet} '#{to_checkout}'")) &&
        run_and_success?("git submodule sync") &&
        run_and_success?("git submodule update --init") &&
        run_and_success?("git clean -dfq")
    end
  end

  # Remove a local branch with the same name as a branch that is being
  # checked out. If there is already a local branch with the same name,
  # then git checkout will checkout the possibly out-of-date local branch
  # instead of the most current remote.
  def clean_local_branch
    run_and_success?("#{git} show-branch #{ref} > /dev/null 2>&1 && #{git} branch -D #{ref} > /dev/null 2>&1")
  end

  # Prune and then fetch origin
  #
  # OR, if origin has changed locations
  #
  # Remove and reclone the repository from url
  def fetch
    run_and_success?(fetch_command)
  end

  # Pruning before fetching makes sure that branches removed from remote are
  # removed locally. This hopefully prevents problems where a branch name
  # collides with a branch directory name (among other problems).
  #
  # Note that --prune doesn't succeed at doing this, even though it seems like
  # it should.
  def fetch_command
    if usable_repository?
      prune_c = "#{git} remote prune origin 2>&1"
      fetch_c = "#{git} fetch --force --prune --update-head-ok #{quiet} origin '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*' 2>&1"

      "#{prune_c} && #{fetch_c}"
    else
      "rm -rf #{repository_cache} && git clone #{quiet} #{uri} #{repository_cache} 2>&1"
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

  def quiet
    @quiet ||= opts[:verbose] ? '' : '--quiet'
  end

end
