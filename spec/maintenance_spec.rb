require 'spec_helper'

describe EY::Serverside::Maintenance do
  let(:maintenance_path) { deploy_dir.join('shared', 'system', 'maintenance.html') }

  context "deployed application" do
    before do
      deploy_test_application
    end

    it "enables the maintenance page" do
      enable_maintenance
      expect(maintenance_path).to exist
    end

    it "disables an enabled maintenance page" do
      enable_maintenance
      expect(maintenance_path).to exist
      disable_maintenance
      expect(maintenance_path).to_not exist
    end

    it "lets you know if the app is in maintenance mode" do
      maintenance_status
      maintenance_output = read_output.split("\n").select{|l| l.match("Maintenance")}
      maintenance_output.count.should == 1
      maintenance_output.first.should match(/Maintenance page: down$/)

      enable_maintenance

      maintenance_status
      maintenance_output = read_output.split("\n").select{|l| l.match("Maintenance")}
      maintenance_output.count.should == 1
      maintenance_output.first.should match(/Maintenance page: up$/)

      disable_maintenance

      maintenance_status
      maintenance_output = read_output.split("\n").select{|l| l.match("Maintenance")}
      maintenance_output.count.should == 1
      maintenance_output.first.should match(/Maintenance page: down$/)
    end
  end
end
