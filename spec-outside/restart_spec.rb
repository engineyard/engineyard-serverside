require 'spec_helper'

class TestRestartDeploy < FullTestDeploy
  attr_reader :call_order
  def initialize(*a)
    super
    @call_order = []
  end

  def require_custom_tasks()                   @call_order << 'require_custom_tasks'                   end
  def restart()                                @call_order << 'restart'                                end
  def enable_maintenance_page()                @call_order << 'enable_maintenance_page'                end
  def disable_maintenance_page()               @call_order << 'disable_maintenance_page'               end
end

describe "EY::Serverside::Deploy#restart_with_maintenance_page" do

  class TestRestartWithMaintenancePage < TestRestartDeploy
    def conditionally_enable_maintenance_page()  @call_order << 'conditionally_enable_maintenance_page'  end
  end

  it "puts up the maintenance page if necessary, restarts, and takes down the maintenance page" do
    config = EY::Serverside::Deploy::Configuration.new('deploy_to' => deploy_dir, 'app' => 'app_name')
    deployer = TestRestartWithMaintenancePage.realnew(test_servers, config, test_shell)
    deployer.restart_with_maintenance_page
    expect(deployer.call_order).to eq(%w(
      require_custom_tasks
      enable_maintenance_page
      restart
      disable_maintenance_page
    ))
  end
end

describe "glassfish stack" do

  it "requires a maintenance page" do
    config = EY::Serverside::Deploy::Configuration.new('deploy_to' => deploy_dir, 'app' => 'app_name', 'stack' => 'glassfish')
    deployer = TestRestartDeploy.realnew(test_servers, config, test_shell)
    deployer.restart_with_maintenance_page
    expect(deployer.call_order).to include('enable_maintenance_page')
  end
end
