require 'spec_helper'

describe "Deploying an application that uses PHP and Composer" do

  context "with composer available" do

    context "with a composer.lock" do
      before(:all) do
        deploy_test_application('php_composer_lock')
      end

      it "runs 'composer install'" do
        install_cmd = @deployer.commands.grep(/composer install/).first
        install_cmd.should_not be_nil
      end

      it "runs 'composer self-update' before 'composer install'" do
        update_cmd = nil
        @deployer.commands.each do |cmd|
          update_cmd ||= /composer self-update/.match(cmd)
          if /composer install/.match(cmd)
            update_cmd.should_not be nil
          end
        end
      end
    end

    context "WITHOUT a composer.lock but with composer.json" do
      before(:all) do
        deploy_test_application('php_no_composer_lock')
      end

      it "runs 'composer install'" do
        install_cmd = @deployer.commands.grep(/composer install/).first
        install_cmd.should_not be_nil
      end

      it "runs 'composer self-update' before 'composer install'" do
        update_cmd = nil
        @deployer.commands.each do |cmd|
          update_cmd ||= /composer self-update/.match(cmd)
          if /composer install/.match(cmd)
            update_cmd.should_not be nil
          end
        end
      end

    end

  end if $COMPOSER_INSTALLED

  context "without composer available" do

    context "with a composer.lock" do
      before(:all) do
        deploy_test_application('php_composer_lock')
      end

      it "outputs a warning, but continues" do
        warning_out = read_output.should include("WARNING: composer.lock")
        warning_out.should_not be_nil
      end
    end

    context "WITHOUT a composer.lock but with composer.json" do
      before(:all) do
        deploy_test_application('php_no_composer_lock')
      end

      it "outputs a warning, but continues" do
        warning_out = read_output.should include("WARNING: composer.json")
        warning_out.should_not be_nil
      end

    end

  end if !$COMPOSER_INSTALLED
end

