require File.dirname(__FILE__) + "/spec_helper"

describe EY::Serverside do
  
  it "preserves the old constants" do
    EY::BundleInstaller.should == EY::Serverside::BundleInstaller
    EY::CLI.should == EY::Serverside::CLI
    EY::Deploy.should == EY::Serverside::Deploy
    EY::DeployBase.should == EY::Serverside::DeployBase
    EY::Deploy::Configuration.should == EY::Serverside::Deploy::Configuration
    EY::DeployHook.should == EY::Serverside::DeployHook
    EY::LockfileParser.should == EY::Serverside::LockfileParser
    EY::LoggedOutput.should == EY::Serverside::LoggedOutput
    EY::Server.should == EY::Serverside::Server
    EY::Task.should == EY::Serverside::Task    
    EY::Strategies.should == EY::Serverside::Strategies
    EY::Strategies::Git.should == EY::Serverside::Strategies::Git
    
    lambda{ EY::WTFNotDefined }.should raise_error(NameError, /uninitialized constant EY::WTFNotDefined/)    

    #TODO: what about EY.node and EY.dna..

  end

end
