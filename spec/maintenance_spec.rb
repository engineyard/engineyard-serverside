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
      expect(maintenance_output.count).to eq(1)
      expect(maintenance_output.first).to match(/Maintenance page: down$/)

      enable_maintenance

      maintenance_status
      maintenance_output = read_output.split("\n").select{|l| l.match("Maintenance")}
      expect(maintenance_output.count).to eq(1)
      expect(maintenance_output.first).to match(/Maintenance page: up$/)

      disable_maintenance

      maintenance_status
      maintenance_output = read_output.split("\n").select{|l| l.match("Maintenance")}
      expect(maintenance_output.count).to eq(1)
      expect(maintenance_output.first).to match(/Maintenance page: down$/)
    end
  end
end
