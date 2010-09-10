require File.dirname(__FILE__) + "/spec_helper"

describe EY::Server do
  before(:each) do
    EY::Server.reset
  end

  context ".all" do
    it "starts off empty" do
      EY::Server.all.should be_empty
    end

    it "is added to with .add" do
      EY::Server.add(:hostname => 'otherhost', :roles => %w[fire water])
      EY::Server.all.size.should == 1

      EY::Server.by_hostname('otherhost').should_not be_nil
    end

    it "rejects duplicates" do
      EY::Server.add(:hostname => 'otherhost')
      lambda do
        EY::Server.add(:hostname => 'otherhost')
      end.should raise_error(EY::Server::DuplicateHostname)
    end
  end

  it "makes sure your roles are symbols at creation time" do
    EY::Server.add(:hostname => 'otherhost', :roles => ['beerguy'])

    EY::Server.by_hostname('otherhost').roles.should == [:beerguy]
  end

  it "makes sure your roles are symbols when updated" do
    EY::Server.add(:hostname => 'otherhost')

    server = EY::Server.by_hostname('otherhost')
    server.roles = %w[bourbon scotch beer]
    server.roles.should == [:bourbon, :scotch, :beer]
  end

  context ".from_roles" do
    before(:each) do
      @localhost = EY::Server.add(:hostname => 'localhost', :roles => [:ice, :cold])
      @host1 = EY::Server.add(:hostname => 'host1', :roles => [:fire, :water])
      @host2 = EY::Server.add(:hostname => 'host2', :roles => [:ice, :water])
    end

    it "works with strings or symbols" do
      EY::Server.from_roles(:fire).should == [@host1]
      EY::Server.from_roles('fire').should == [@host1]
    end

    it "finds all servers with the specified role" do
      EY::Server.from_roles('ice').size.should == 2
      EY::Server.from_roles('ice').sort do |a, b|
        a.hostname <=> b.hostname
      end.should == [@host2, @localhost]
    end

    it "finds all servers with any of the specified roles" do
      EY::Server.from_roles(:ice, :water).should == EY::Server.all
    end

    it "returns everything when asked for :all" do
      EY::Server.from_roles(:all).should == EY::Server.all
    end
  end

  context "#local?" do
    it "is true only for localhost" do
      EY::Server.new('localhost').should be_local
      EY::Server.new('neighborhost').should_not be_local
    end
  end
end
