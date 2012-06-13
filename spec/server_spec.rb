require 'spec_helper'

describe EY::Serverside::Server do
  it "starts off empty" do
    EY::Serverside::Servers.new([]).should be_empty
  end

  it "loads from hashes" do
    servers = EY::Serverside::Servers.from_hashes([{:hostname => 'otherhost', :roles => %w[fire water]}])
    servers.size.should == 1
  end

  it "rejects duplicates" do
    lambda do
      EY::Serverside::Servers.from_hashes([
        {:hostname => 'otherhost', :roles => [:fire]},
        {:hostname => 'otherhost', :roles => [:water]},
      ])
    end.should raise_error(EY::Serverside::Servers::DuplicateHostname)
  end

  it "makes sure your roles are symbols at creation time" do
    servers = EY::Serverside::Servers.from_hashes([{:hostname => 'otherhost', :roles => %w[fire water]}])
    servers.each { |server| server.roles.should == Set[:fire, :water] }
  end

  context "filtering" do
    before(:each) do
      @servers = EY::Serverside::Servers.from_hashes([
        {:hostname => 'localhost', :roles => [:ice, :cold]},
        {:hostname => 'firewater', :roles => [:fire, :water]},
        {:hostname => 'icewater',  :roles => [:ice, :water]},
      ])
    end

    it "#roles works with strings or symbols" do
      @servers.roles(:fire ).map{|s| s.hostname}.should == ['firewater']
      @servers.roles('fire').map{|s| s.hostname}.should == ['firewater'] # hits the cache the second time
    end

    it "#roles finds all servers with the specified role" do
      @servers.roles(:ice).size.should == 2
      @servers.roles(:ice).map{|s| s.hostname}.sort.should == ['icewater','localhost']
    end

    it "#roles finds all servers with any of the specified roles" do
      @servers.roles(:ice, :water).should == @servers
    end

    it "#roles returns everything when asked for :all" do
      @servers.roles(:all).should == @servers
    end

    it "#roles also yields filtered server set" do
      @servers.roles(:ice) do |servers|
        servers.size.should == 2
        servers.map{|s| s.hostname}.sort.should == ['icewater','localhost']
      end
    end

    it "#localhost returns the localhost server" do
      @servers.localhost.hostname.should == 'localhost'
    end

    it "#remote returns non-localhost servers" do
      @servers.remote.size.should == 2
      @servers.remote.map {|s| s.hostname}.sort.should == ['firewater','icewater']
    end
  end
end
