require 'spec_helper'

describe "Rolling back" do
  def setup_good_and_bad_deploy(repo)
    deploy_test_application(repo, 'migrate' => nil)
    @good_revision = deploy_dir.join('current', 'REVISION').read.strip
    expect(deploy_dir.join('current', 'REVISION')).to exist
    deploy_dir.join('current', 'restart').delete
    deploy_test_application(repo, 'migrate' => nil)
    expect(deploy_dir.join('current', 'REVISION')).to exist
    deploy_dir.join('current', 'restart').delete

    releases = @deployer.config.paths.all_releases
    expect(releases.size).to eq(2)
    @good_release = releases.first
    @bad_release = releases.last
  end

  def rollback
    argv = @adapter.rollback.commands.last.to_argv[2..-1]
    with_mocked_commands do
      capture do
        EY::Serverside::CLI.start(argv)
      end
    end
  end

  context "without bundler" do
    before(:all) do
      setup_good_and_bad_deploy('not_bundled')
      rollback
    end

    it "rolls back to the older deploy" do
      out = read_output
      expect(out).to match(/Rolling back to previous release.*#{@good_revision}/)
      expect(out).to match(/Restarting with previous release./)
      expect(out).to match(/Finished rollback/)

      expect(deploy_dir.join('current', 'restart')).to exist
      expect(@bad_release).not_to exist
      expect(@good_release.join('restart')).to exist
    end
  end

  context "with a problematic file in the releases dir" do
    before(:all) do
      setup_good_and_bad_deploy('not_bundled')
      @deployer.config.paths.releases.join('tmp').mkpath
      expect { rollback }.to raise_error
    end

    it "rolls back to the older deploy" do
      out = read_output
      expect(out).to include("Bad paths found in #{@deployer.config.paths.releases}:")
      expect(out).to include(@deployer.config.paths.releases.join('tmp').to_s)
      expect(out).to include("Storing files in this directory will disrupt latest_release, diff detection, rollback, and possibly other features.")
      expect(out).to_not include("Restarting with previous release.")

      expect(deploy_dir.join('current', 'restart')).not_to exist
      expect(@bad_release).to exist
      expect(@good_release).to exist
    end
  end

  context "with complex config" do
    before(:all) do
      setup_good_and_bad_deploy('ey_yml')
      rollback
    end

    it "rolls back to the older deploy" do
      out = read_output
      expect(out).to match(/Rolling back to previous release.*#{@good_revision}/)
      expect(out).to match(/Restarting with previous release./)
      expect(out).to match(/Finished rollback/)

      expect(deploy_dir.join('current', 'restart')).to exist
      expect(@bad_release).not_to exist
      expect(@good_release.join('restart')).to exist
    end

    it "loads and uses ey.yml during rollback" do
      expect(read_output).to match(/--without only test/)
    end
  end
end
