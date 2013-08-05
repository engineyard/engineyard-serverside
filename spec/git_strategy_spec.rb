require 'spec_helper'

class EY::Serverside::Source::Git
  def fetch_command
    "mkdir -p #{source_cache} && tar xzf #{FIXTURES_DIR.join('gitrepo.tar.gz')} --strip-components 1 -C #{source_cache}"
  end
end

describe EY::Serverside::Source::Git do
  before do
    @source_cache = tmpdir.join("gitrepo-#{Time.now.utc.strftime("%Y%m%d%H%M%S")}#{Time.now.tv_usec}-#{$$}")
  end


  it "#update_repository_cache returns true for branches that exist" do
    git = EY::Serverside::Source::Git.new(
      test_shell,
      :uri => FIXTURES_DIR.join('repos','default'),
      :repository_cache => @source_cache,
      :ref => "somebranch"
    )
    git.update_repository_cache
  end

  it "#update_repository_cache returns false for branches that do not exist" do
    git = EY::Serverside::Source::Git.new(
      test_shell,
      :uri => FIXTURES_DIR.join('repos','default'),
      :repository_cache => @source_cache,
      :ref => "notabranch"
    )
    expect { git.update_repository_cache }.to raise_error
  end
end
