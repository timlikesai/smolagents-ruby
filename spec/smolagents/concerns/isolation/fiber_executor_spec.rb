require "spec_helper"

RSpec.describe Smolagents::Concerns::Isolation::FiberExecutor do
  let(:limits) { Smolagents::Types::Isolation::ResourceLimits.default }

  describe ".execute" do
    it "executes block and returns result" do
      result = described_class.execute(limits:) { 42 }

      expect(result.value).to eq(42)
      expect(result.success?).to be true
    end

    it "captures successful execution" do
      result = described_class.execute(limits:) { "hello" }

      expect(result.success?).to be true
      expect(result.value).to eq("hello")
    end

    it "captures exceptions" do
      result = described_class.execute(limits:) { raise "boom" }

      expect(result.success?).to be false
      expect(result.error).to be_a(RuntimeError)
      expect(result.error.message).to eq("boom")
    end

    it "delegates to ThreadExecutor" do
      allow(Smolagents::Concerns::Isolation::ThreadExecutor).to receive(:execute).and_call_original

      described_class.execute(limits:) { 1 + 1 }

      expect(Smolagents::Concerns::Isolation::ThreadExecutor).to have_received(:execute)
    end
  end
end
