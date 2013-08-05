require 'spec_helper'

describe EY::Serverside::Source::Git do
  before do
    described_class.any_instance.stub(:runner) { RunnerDouble }
  end

  it "errors when required options are not used" do
    expect { described_class.new(nil, {}) }.to raise_error(ArgumentError)
  end

  context "source" do
    let(:shell) { ShellDouble.new }
    subject {
      described_class.new(shell,
        :uri => "engineyard/engineyard-serverside.git",
        :ref => "",
        :repository_cache => "cache_dir")
    }

    it "creates the correct reivison file command" do
      expect(subject.create_revision_file_command("directory/REVISION")).to eq(
        "git --git-dir cache_dir/.git --work-tree cache_dir show --pretty=format:\"%H\" | head -1 > \"directory/REVISION\""
      )
    end

    it "runs gc" do
      expect(subject.gc_repository_cache.output).to eq("git --git-dir cache_dir/.git --work-tree cache_dir gc")
      expect(shell.messages.last).to eq("Garbage collecting cached git repository to reduce disk usage.")
    end

    it "checks if it is the same revision" do
      expect(subject.same?("", "")).to be
    end

    it "runs a short log message" do
      expect(subject.short_log_message("rev")).to eq(
        "git --git-dir cache_dir/.git --work-tree cache_dir log --pretty=oneline --abbrev-commit -n 1 'rev'"
      )
    end

  end

end
