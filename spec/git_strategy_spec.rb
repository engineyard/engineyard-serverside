require 'spec_helper'

describe EY::Serverside::Strategy::Git do
  before do
    @gitrepo_dir = tmpdir.join("gitrepo-#{Time.now.utc.strftime("%Y%m%d%H%M%S")}#{Time.now.tv_usec}-#{$$}")
    @gitrepo_dir.mkdir
    system "tar xzf #{FIXTURES_DIR.join('gitrepo.tar.gz')} --strip-components 1 -C #{@gitrepo_dir}"
  end


  it "#update_repository_cache returns true for branches that exist" do
    git = EY::Serverside::Strategy::Git.new(
      test_shell,
      :uri => FIXTURES_DIR.join('repos','default'),
      :repository_cache => @gitrepo_dir,
      :ref => "somebranch"
    )
    git.update_repository_cache#checkout.should be_true
  end

  it "#update_repository_cache returns false for branches that do not exist" do
    git = EY::Serverside::Strategy::Git.new(
      test_shell,
      :uri => FIXTURES_DIR.join('repos','default'),
      :repository_cache => @gitrepo_dir,
      :ref => "notabranch"
    )
    expect { git.update_repository_cache }.to raise_error
  end
end
