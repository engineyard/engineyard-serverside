require 'spec_helper'

describe "Deploying an application that uses PHP and Composer" do

  with_composer_mocked do |mocked|
    context "with composer available" do
      before(:all) { mock_composer if mocked }

      context "with a composer.lock" do
        before(:all) do
          deploy_test_application('php_composer_lock')
        end

        it "runs 'composer install'" do
          install_cmd = @deployer.commands.grep(/composer install/).first
          install_cmd.should_not be_nil
        end

        it "attempts to run 'composer self-update' before 'composer install'" do
          update_cmd = nil
          @deployer.commands.each do |cmd|
            update_cmd ||= /composer.*self-update/.match(cmd)
            if /composer install/.match(cmd)
              update_cmd.should_not be nil
            end
          end
        end
      end

      context "with composer disabled in ey.yml" do
        before(:all) do
          deploy_test_application('php_composer_disabled')
        end

        it "does not run composer" do
          @deployer.commands.grep(/composer/).should be_empty
        end
      end

      context "WITHOUT a composer.lock but with composer.json" do
        before(:all) do
          deploy_test_application('php_no_composer_lock')
        end

        it "outputs a warning about deploying without a .lock" do
          warning_out = read_output.should include("WARNING: composer.json found but composer.lock missing!")
          warning_out.should_not be_nil
        end

        it "runs 'composer install'" do
          install_cmd = @deployer.commands.grep(/composer install/).first
          install_cmd.should_not be_nil
        end

        it "attempts to run 'composer self-update' before 'composer install'" do
          update_cmd = nil
          @deployer.commands.each do |cmd|
            update_cmd ||= /composer.*self-update/.match(cmd)
            if /composer install/.match(cmd)
              update_cmd.should_not be nil
            end
          end
        end

      end

    end

    unless $COMPOSER_INSTALLED
      context "without composer available" do

        it "fails to deploy" do
          expect {deploy_test_application('php_composer_lock')}.to raise_error EY::Serverside::RemoteFailure
          expect {deploy_test_application('php_no_composer_lock')}.to raise_error EY::Serverside::RemoteFailure
        end

      end
    end
  end
end

