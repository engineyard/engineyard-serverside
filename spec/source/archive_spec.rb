require 'spec_helper'

describe EY::Serverside::Source::Archive do
  before do
    allow_any_instance_of(described_class).to receive(:runner) { RunnerDouble }
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
      subject.update_repository_cache
    end

  end
end
