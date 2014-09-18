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
  end
end
