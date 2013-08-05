require 'engineyard-serverside/source'

# Deploy source for archive sourced deploy.
class EY::Serverside::Source::Archive < EY::Serverside::Source
  def create_revision_file_command(revision_file_path)
    "echo #{escape(@checksum || filename)} > #{escape(revision_file_path.to_s)}"
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
      fetch && checksum && unarchive
    end
  end

  protected

  def checksum
    @checksum = run_and_output("shasum #{escape(File.join(source_cache, filename))}").strip
  end

  def clean_cache
    run "rm -rf #{source_cache} && mkdir -p #{source_cache}"
  end

  def fetch_command
    "curl --location --silent --show-error -O --user-agent #{escape("EngineYardDeploy/#{EY::Serverside::VERSION}")} #{escape(uri)}"
  end

  def fetch
    run_and_success?(fetch_command)
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
