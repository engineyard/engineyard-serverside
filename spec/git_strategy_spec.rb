require File.dirname(__FILE__) + '/spec_helper'

describe "the git deploy strategy" do
  subject do
    EY::Strategies::Git.new(:repo => File.expand_path("../fixtures/gitrepo/.git", __FILE__),
                            :repository_cache => File.expand_path("../fixtures/gitrepo", __FILE__),
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
