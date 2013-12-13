require 'spec_helper'

describe "Deploying an application that uses Node.js and NPM" do
  with_composer_mocked do |composer_mocked|
    with_npm_mocked do |npm_mocked|

      before(:all) do
        mock_composer if composer_mocked
        mock_npm if npm_mocked
        deploy_test_application('multi_dep_manager')
      end

      it "runs 'npm install' and 'composer install'" do
        npm_cmd = @deployer.commands.grep(/npm install/).first
        npm_cmd.should_not be_nil

        update_cmd = @deployer.commands.grep(/composer.*self-update/).first
        update_cmd.should_not be_nil

        composer_cmd = @deployer.commands.grep(/composer install/).first
        composer_cmd.should_not be_nil
      end
    end
  end
end
