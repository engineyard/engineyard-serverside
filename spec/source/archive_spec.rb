require 'spec_helper'

describe EY::Serverside::Source::Archive do
  before do
    described_class.any_instance.stub(:runner) { RunnerDouble }
  end

  context "source" do
    let(:shell) { ShellDouble.new }
    subject {
      described_class.new(shell,
        :uri => "http://server.com/app.war",
        :repository_cache => TMPDIR)
    }

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
