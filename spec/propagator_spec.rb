require 'spec_helper'

describe EY::Serverside::Propagator do
  let(:config) do
    EY::Serverside::Deploy::Configuration.new({
      'app'       => 'app',
      'deploy_to' => deploy_dir.to_s,
      'user'      => ENV['USER'],
    })
  end

  let(:servers) do
    EY::Serverside::Servers.from_hashes(
      [
        {:user => config.user, :hostname => 'localhost', :roles => %w[solo]},
        {:user => config.user, :hostname => '127.0.0.1', :roles => %w[util], :name => 'myutil'},
      ]
    )
  end

  let(:solo) { servers.roles(:solo).first }
  let(:util) { servers.roles(:util).first }

  let(:shell)       { mock('shell') }
  let(:check_command)   { util.command_on_server('sh -l -c', subject.check_command) }
  let(:scp_command)     { subject.scp_command(util) }
  let(:install_command) { util.command_on_server('sudo sh -l -c', subject.install_command) }

  subject do
    EY::Serverside::Propagator.new(servers, config, shell)
  end

  def stub_shell_command(command, success, output="STUB OUTPUT")
    shell.should_receive(:logged_system).once.ordered.with(command).and_return do
      test_shell.command_show(command)
      EY::Serverside::Shell::CommandResult.new(command, success ? 0 : 1, output)
    end
  end

  before do
    shell.stub(:status) do |msg|
      test_shell.status(msg) # hax so you can see the output with VERBOSE
    end
  end

  context "no remote servers" do
    subject { EY::Serverside::Propagator.new(test_servers, config, shell) }

    it "returns without doing anything" do
      shell.should_not_receive(:logged_system)
      subject.call
    end
  end

  context "all servers have the gem" do
    before do
      stub_shell_command(check_command, true)
      shell.should_not_receive(:logged_system).with(scp_command)
      shell.should_not_receive(:logged_system).with(install_command)
    end

    it "finds no servers" do
      subject.servers.should be_empty
      subject.call
    end
  end

  context "with a server missing the gem" do
    before do
      stub_shell_command(check_command, false)
    end

    it "finds servers that need the gem installed and installs it" do
      stub_shell_command(scp_command, true)
      stub_shell_command(install_command, true)

      subject.servers.to_a.should == [util]
      subject.call
    end

    it "raises if the scp fails" do
      stub_shell_command(scp_command, false)
      shell.should_not_receive(:logged_system).with(install_command)

      lambda { subject.call }.should raise_error(EY::Serverside::RemoteFailure)
    end

    it "raises if the install fails" do
      stub_shell_command(scp_command, true)
      stub_shell_command(install_command, false)

      lambda { subject.call }.should raise_error(EY::Serverside::RemoteFailure)
    end
  end
end
