# Deploy strategy for archive source based deploy.
class EY::Serverside::Strategy::Archive < EY::Serverside::Strategy
  def create_revision_file_command(revision_file_path)
    "echo #{escape(filename)} > #{escape(revision_file_path)}"
  end

  def gc_repository_cache
    # If files are uploaded to the server, we should clean them up here probably.
  end

  def same?(previous_rev, current_rev, paths=nil)
    previous_rev == current_rev
  end

  def short_log_message(rev)
    rev
  end

  def update_repository_cache
    clean_cache
    in_source_cache do
      fetch
      unarchive
    end
  end

  protected

  def clean_cache
    run "rm -rf #{source_cache} && mkdir -p #{source_cache}"
  end

  def fetch
    cmd = %w[curl --location --silent --show-error -O --user-agent] + ["EngineYardDeploy/#{EY::Serverside::VERSION}", uri]
    run Escape.shell_command(cmd)
  end

  def filename
    @filename ||= File.basename(URI.parse(uri).path)
  end

  def unarchive
    case File.extname(filename)
    when '.zip', '.war'
      run "unzip #{filename} && rm #{filename}"
    end
  end
end
