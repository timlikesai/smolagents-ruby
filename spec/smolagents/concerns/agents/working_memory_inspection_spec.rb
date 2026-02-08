RSpec.describe Smolagents::Concerns::WorkingMemory, "#memory_token_estimate and #memory_summary" do
  let(:host) do
    Class.new do
      include Smolagents::Concerns::WorkingMemory

      def initialize = initialize_working_memory
    end.new
  end

  describe "#memory_token_estimate" do
    it "returns 0 for empty memory" do
      expect(host.memory_token_estimate).to eq(0)
    end

    it "estimates tokens based on content length" do
      host.update_objective("Find Ruby release notes")
      expect(host.memory_token_estimate).to be > 0
    end
  end

  describe "#memory_summary" do
    it "shows empty for fresh memory" do
      expect(host.memory_summary).to include("empty")
    end

    it "includes objective status" do
      host.update_objective("Test")
      expect(host.memory_summary).to include("objective: set")
    end

    it "includes finding count" do
      host.record_finding("Found something")
      expect(host.memory_summary).to include("1 findings")
    end

    it "includes blocker count" do
      host.record_blocker("Rate limited")
      expect(host.memory_summary).to include("1 blockers")
    end
  end
end
