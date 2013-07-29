require 'spec_helper'

describe EY::Serverside::Strategy::Archive do
  before do
    described_class.any_instance.stub(:runner) { RunnerDouble }
  end

  context "strategy" do
    let(:shell) { ShellDouble.new }
    subject {
      described_class.new(shell,
        :uri => "http://server.com/app.war",
        :repository_cache => TMPDIR)
    }

    it "creates the correct revision command using the filename" do
      expect(subject.create_revision_file_command("directory/REVISION")).to eq(
        "shasum #{File.join(subject.source_cache, "app.war")} > directory/REVISION"
      )
    end

    it "cleans cache" do
      expect(subject).to respond_to(:gc_repository_cache)
    end

    it "compares revisions" do
      expect(subject.same?("1", "1")).to be
    end

    it "understands short log message" do
      expect(subject).to respond_to(:short_log_message)
    end

    it "updates the cache" do
      last_output = subject.update_repository_cache.output
      expect(last_output).to eq("unzip app.war && rm app.war")
    end

  end
end
