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

  class Thin < Mongrel
    task_overrides do
      def foobar
      end
    end
  end
end

describe EY::Stack do
  shared_examples_for "the mongrel stack" do
    specify { subject.roles_for(:restart).should == [ :some, :roles, :here ] }
    specify { subject.task_overrides.instance_methods.should include("restart") }
    its(:task_overrides) { should be_a Module }
  end

  describe "for mongrel on xcloud" do
    subject { EY::Stack.use("foocloud", "mongrel") }

    it_should_behave_like "the mongrel stack"
  end

  describe "should handle attributes for inherited classes" do
    subject { EY::Stack::FooCloud::Thin.new }

    it_should_behave_like "the mongrel stack"
    specify { subject.task_overrides.instance_methods.should include("foobar") }
  end
end
