require 'spec_helper'

describe "Deploying an application with conflicting directories" do
  before(:all) do
    deploy_test_application('public_system')
  end

  it "does not remove the repository's public/system directory" do
    expect(deploy_dir.join('current', 'public', 'system', 'cant_touch_this.txt')).to exist
  end

  it "warns that maintenance pages are broken" do
    expect(read_output).to include("remove 'public/system' from your repository")
  end
end
