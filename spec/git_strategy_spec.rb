require 'spec_helper'

describe "the git deploy strategy" do
  subject do
    fixtures_dir = Pathname.new(__FILE__).dirname.join("fixtures")
    gitrepo_dir = tmpdir.join("gitrepo-#{Time.now.utc.strftime("%Y%m%d%H%M%S%L")}-#{$$}")
    gitrepo_dir.mkdir
    system "tar xzf #{fixtures_dir.join('gitrepo.tar.gz')} --strip-components 1 -C #{gitrepo_dir}"

    EY::Serverside::Strategies::Git.new(
      test_shell,
      :repo => FIXTURES_DIR.join('repos','default'),
      :repository_cache => gitrepo_dir,
      :ref => "master"
    )
  end

  before { subject.checkout }

  it "#checkout returns true for branches that exist" do
    subject.opts[:ref] = "somebranch"
    subject.checkout.should be_true
  end

  it "#checkout returns false for branches that do not exist" do
    subject.opts[:ref] = "notabranch"
    subject.checkout.should be_false
  end
end
