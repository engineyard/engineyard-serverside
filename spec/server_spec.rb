require File.dirname(__FILE__) + "/spec_helper"

describe EY::Server do
  describe "with multiple roles" do
    subject { EY::Server.new("foobar", ["app", "lb"], "foo") }

    its(:roles) { should == [:app, :lb] }

    describe "assigned by #all=" do
      before { 
        EY::Server.all = [ 
          { :hostname => "foobar", :roles => ["app", "lb"], :name => "foo" },
          { :hostname => "barbaz", :roles => ["db", "memcached"], :name => "bar" },
          { :hostname => "barbaz", :role => "memcached", :name => "bar" }
        ]
      }
      
      it "can be found by #from_roles" do
        EY::Server.from_roles(:app, :memcached).should == EY::Server.all
      end

      it "can find individual servers by role" do
        EY::Server.from_roles(:app).should == [EY::Server.all.first]
      end

      it "can find multiple servers with the same role" do
        EY::Server.from_roles(:memcached).should == EY::Server.all[1..2]
      end
    end
  end
end
