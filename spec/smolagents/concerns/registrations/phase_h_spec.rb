RSpec.describe "Phase H concern registrations", type: :integration do
  let(:registry) { Smolagents::Concerns::Registry }

  describe "agent concerns" do
    it "registers stats_tracking" do
      entry = registry[:stats_tracking]
      expect(entry).not_to be_nil
      expect(entry.module_path).to eq("Smolagents::Concerns::StatsTracking")
      expect(entry.category).to eq(:agents)
      expect(entry.provides).to include(:stats)
    end

    it "registers verbose_subscriber" do
      entry = registry[:verbose_subscriber]
      expect(entry).not_to be_nil
      expect(entry.module_path).to eq("Smolagents::Concerns::VerboseSubscriber")
      expect(entry.category).to eq(:agents)
    end
  end

  describe "resilience concerns" do
    it "registers failure_capture" do
      entry = registry[:failure_capture]
      expect(entry).not_to be_nil
      expect(entry.module_path).to eq("Smolagents::Concerns::Resilience::FailureCapture")
      expect(entry.category).to eq(:resilience)
      expect(entry.provides).to include(:last_failures, :last_failure, :failure_count)
    end
  end
end
