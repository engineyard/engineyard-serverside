require 'spec_helper'

describe EY::Serverside::Server do
  it "starts off empty" do
    expect(EY::Serverside::ServerCollection.new([], test_shell)).to be_empty
  end

  it "loads from hashes" do
    servers = EY::Serverside::ServerCollection.from_hashes([{:hostname => 'otherhost', :roles => %w[fire water]}], test_shell)
    expect(servers.size).to eq(1)
  end

  it "rejects duplicates" do
    expect do
      EY::Serverside::ServerCollection.from_hashes([
        {:hostname => 'otherhost', :roles => [:fire]},
        {:hostname => 'otherhost', :roles => [:water]},
      ], test_shell)
    end.to raise_error(EY::Serverside::ServerCollection::DuplicateHostname)
  end

  it "makes sure your roles are symbols at creation time" do
    servers = EY::Serverside::ServerCollection.from_hashes([{:hostname => 'otherhost', :roles => %w[fire water]}], test_shell)
    servers.each { |server| expect(server.roles).to eq(Set[:fire, :water]) }
  end

  context "filtering" do
    before(:each) do
      @servers = EY::Serverside::ServerCollection.from_hashes([
        {:hostname => 'localhost', :roles => [:ice, :cold]},
        {:hostname => 'firewater', :roles => [:fire, :water]},
        {:hostname => 'icewater',  :roles => [:ice, :water]},
      ], test_shell)
    end

    it "#roles works with strings or symbols" do
      expect(@servers.roles(:fire ).map{|s| s.hostname}).to eq(['firewater'])
      expect(@servers.roles('fire').map{|s| s.hostname}).to eq(['firewater']) # hits the cache the second time
    end

    it "#roles finds all servers with the specified role" do
      expect(@servers.roles(:ice).size).to eq(2)
      expect(@servers.roles(:ice).map{|s| s.hostname}.sort).to eq(['icewater','localhost'])
    end

    it "#roles finds all servers with any of the specified roles" do
      expect(@servers.roles(:ice, :water)).to eq(@servers)
    end

    it "#roles returns everything when asked for :all" do
      expect(@servers.roles(:all)).to eq(@servers)
    end

    it "#roles also yields filtered server set" do
      @servers.roles(:ice) do |servers|
        expect(servers.size).to eq(2)
        expect(servers.map{|s| s.hostname}.sort).to eq(['icewater','localhost'])
      end
    end

    it "#localhost returns the localhost server" do
      expect(@servers.localhost.hostname).to eq('localhost')
    end

    it "#remote returns non-localhost servers" do
      expect(@servers.remote.size).to eq(2)
      expect(@servers.remote.map {|s| s.hostname}.sort).to eq(['firewater','icewater'])
    end
  end
end
