require File.dirname(__FILE__) + "/spec_helper"

describe "The Metadata abstraction layer" do
  it "should select the right provider" do
    meta = EY::Metadata.for("xcloud")
    meta.should be_a_kind_of EY::Metadata::XdnaProvider

    meta = EY::Metadata.for("appcloud")
    meta.should be_a_kind_of EY::Metadata::DnaJsonProvider
  end

  it "should raise an error with unknown providers" do
    lambda { EY::Metadata.for("somecloud") }.should raise_error
  end
end

share_examples_for 'metadata' do
  its(:roles) { should == %w( solo ) }
  its(:role) { should == "solo" }
end

describe EY::Metadata::DnaJsonProvider do
  before {
    EY::Metadata::DnaJsonProvider.dna_json = %Q!{ "instance_role": "solo" }!
  }

  it_should_behave_like 'metadata'
end

describe EY::Metadata::XdnaProvider do
end
