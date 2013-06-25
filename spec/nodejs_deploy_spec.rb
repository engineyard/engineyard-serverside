require 'spec_helper'

describe "Deploying an application that uses Node.js and NPM" do
  with_npm_mocked do |mocked|
    before(:all) do
      mock_npm if mocked
      deploy_test_application('nodejs')
    end

    it "runs 'npm install'" do
      install_cmd = @deployer.commands.grep(/npm install/).first
      install_cmd.should_not be_nil
    end
  end
end
