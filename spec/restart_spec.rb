require File.dirname(__FILE__) + '/spec_helper'

class TestRestartDeploy < EY::Serverside::Deploy
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
    deployer = TestRestartWithMaintenancePage.new(EY::Serverside::Deploy::Configuration.new)
    deployer.restart_with_maintenance_page
    deployer.call_order.should == %w(
      require_custom_tasks
      conditionally_enable_maintenance_page
      restart
      disable_maintenance_page
    )
  end
end

describe "glassfish stack" do

  it "requires a maintenance page" do
    config = EY::Serverside::Deploy::Configuration.new(:stack => 'glassfish')
    deployer = TestRestartDeploy.new(config)
    deployer.restart_with_maintenance_page
    deployer.call_order.should include('enable_maintenance_page')
  end
end
