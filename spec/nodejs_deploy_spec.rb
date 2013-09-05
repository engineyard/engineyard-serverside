require 'spec_helper'

describe "Deploying an application that uses Node.js and NPM" do
  with_npm_mocked do |mocked|
    before(:all) do
      mock_npm if mocked
    end

    context "npm in detect mode" do
      before do
        deploy_test_application('nodejs')
      end

      it "runs 'npm install'" do
        install_cmd = @deployer.commands.grep(/npm install/).first
        install_cmd.should_not be_nil
      end
    end

    context "npm disabled" do
      before do
        deploy_test_application('npm_disabled')
      end

      it "does not run 'npm install'" do
        @deployer.commands.grep(/npm/).should be_empty
      end
    end
  end
end
