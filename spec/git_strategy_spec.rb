require 'spec_helper'

describe "the git deploy strategy" do
  subject do
    EY::Serverside::Strategies::Git.new(:repo => File.join(GITREPO_DIR, 'git'),
                                        :repository_cache => GITREPO_DIR, :ref => "master")
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
