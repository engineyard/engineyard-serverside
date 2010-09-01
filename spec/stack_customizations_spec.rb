require File.dirname(__FILE__) + "/spec_helper"

module EY::Stack::FooCloud
  class Mongrel < EY::Stack
    register 'foocloud', 'mongrel'

    roles_for :restart, :some, :roles, :here
    
    task_overrides do
      def restart
        "fc-mongrel restarting"
      end
    end
  end
end

describe "the EY::Deploy API" do
  describe "with a stack" do
    subject { EY::Deploy.new(EY::Deploy::Configuration.new("infrastructure" => "foocloud", "stack" => "mongrel")) }
    its(:restart) { should == "fc-mongrel restarting" }
  end
end
