require File.dirname(__FILE__) + '/spec_helper'
require 'ostruct'

class GeneralDelegate < EY::DeployDelegate::Base
  register :somecloud
end

class IgnoredDelegate < EY::DeployDelegate::Base
  register :othercloud
end

class SpecificDelegate < EY::DeployDelegate::Base
  register :othercloud, :otherstack
end

describe "Deploy Delegates" do
  def find_delegate(infra, stack)
    EY::DeployDelegate.for(OpenStruct.new(:config => { 'infrastructure' => infra, 'stack' => stack }))
  end

  it "should find specific ones first" do
    find_delegate(:othercloud, :otherstack).should be_a(SpecificDelegate)
  end

  it "should fall back to generic ones" do
    find_delegate(:somecloud, :somestack).should be_a(GeneralDelegate)
  end

  it "should fail when a delegate can't be found" do
    lambda { find_delegate(:meatcloud, :meatstack) }.should raise_error
  end
end
