require 'spec_helper'

describe "Deploying an application that uses Node.js and NPM" do
  before(:all) do
    deploy_test_application('nodejs')
  end

  it "runs 'npm install'" do
    install_cmd = @deployer.commands.grep(/npm install/).first
    install_cmd.should_not be_nil
  end
end if $NPM_INSTALLED


