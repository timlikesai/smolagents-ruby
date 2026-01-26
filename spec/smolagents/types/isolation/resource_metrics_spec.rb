require "smolagents"

RSpec.describe Smolagents::Types::Isolation::ResourceMetrics do
  let(:instance) { described_class.new(duration_ms: 1000, memory_bytes: 1024, output_bytes: 512) }

  it_behaves_like "a data type"

  describe ".zero" do
    subject(:metrics) { described_class.zero }

    it "returns a ResourceMetrics instance" do
      expect(metrics).to be_a(described_class)
    end

    it "has zero duration" do
      expect(metrics.duration_ms).to eq(0)
    end

    it "has zero memory" do
      expect(metrics.memory_bytes).to eq(0)
    end

    it "has zero output" do
      expect(metrics.output_bytes).to eq(0)
    end

    it "is frozen" do
      expect(metrics).to be_frozen
    end
  end

  describe ".with_duration" do
    subject(:metrics) { described_class.with_duration(500) }

    it "sets duration" do
      expect(metrics.duration_ms).to eq(500)
    end

    it "sets zero memory" do
      expect(metrics.memory_bytes).to eq(0)
    end

    it "sets zero output" do
      expect(metrics.output_bytes).to eq(0)
    end

    it "handles large durations" do
      metrics = described_class.with_duration(1_000_000)
      expect(metrics.duration_ms).to eq(1_000_000)
    end
  end

  describe "#within_limits?" do
    let(:limits) { Smolagents::Types::Isolation::ResourceLimits.default }

    context "when all metrics are within limits" do
      let(:metrics) do
        described_class.new(
          duration_ms: 1000,       # 1 second < 5 seconds
          memory_bytes: 1_000_000, # 1MB < 50MB
          output_bytes: 1_000      # 1KB < 50KB
        )
      end

      it "returns true" do
        expect(metrics.within_limits?(limits)).to be true
      end
    end

    context "when duration exceeds limit" do
      let(:metrics) do
        described_class.new(
          duration_ms: 10_000,     # 10 seconds > 5 seconds
          memory_bytes: 1_000_000,
          output_bytes: 1_000
        )
      end

      it "returns false" do
        expect(metrics.within_limits?(limits)).to be false
      end
    end

    context "when memory exceeds limit" do
      let(:metrics) do
        described_class.new(
          duration_ms: 1_000,
          memory_bytes: 100_000_000, # 100MB > 50MB
          output_bytes: 1_000
        )
      end

      it "returns false" do
        expect(metrics.within_limits?(limits)).to be false
      end
    end

    context "when output exceeds limit" do
      let(:metrics) do
        described_class.new(
          duration_ms: 1_000,
          memory_bytes: 1_000_000,
          output_bytes: 100_000 # 100KB > 50KB
        )
      end

      it "returns false" do
        expect(metrics.within_limits?(limits)).to be false
      end
    end

    context "when exactly at limits" do
      let(:metrics) do
        described_class.new(
          duration_ms: 5_000,              # exactly 5 seconds
          memory_bytes: 50 * 1024 * 1024,  # exactly 50MB
          output_bytes: 50 * 1024          # exactly 50KB
        )
      end

      it "returns true" do
        expect(metrics.within_limits?(limits)).to be true
      end
    end
  end

  describe "#duration_within?" do
    let(:limits) { Smolagents::Types::Isolation::ResourceLimits.with_timeout(5.0) }

    it "returns true when duration is within timeout" do
      metrics = described_class.new(duration_ms: 4_000, memory_bytes: 0, output_bytes: 0)
      expect(metrics.duration_within?(limits)).to be true
    end

    it "returns false when duration exceeds timeout" do
      metrics = described_class.new(duration_ms: 6_000, memory_bytes: 0, output_bytes: 0)
      expect(metrics.duration_within?(limits)).to be false
    end

    it "returns true when duration equals timeout" do
      metrics = described_class.new(duration_ms: 5_000, memory_bytes: 0, output_bytes: 0)
      expect(metrics.duration_within?(limits)).to be true
    end
  end

  describe "#memory_within?" do
    let(:limits) { Smolagents::Types::Isolation::ResourceLimits.default }

    it "returns true when memory is within limit" do
      metrics = described_class.new(duration_ms: 0, memory_bytes: 1_000_000, output_bytes: 0)
      expect(metrics.memory_within?(limits)).to be true
    end

    it "returns false when memory exceeds limit" do
      metrics = described_class.new(duration_ms: 0, memory_bytes: 100_000_000, output_bytes: 0)
      expect(metrics.memory_within?(limits)).to be false
    end
  end

  describe "#output_within?" do
    let(:limits) { Smolagents::Types::Isolation::ResourceLimits.default }

    it "returns true when output is within limit" do
      metrics = described_class.new(duration_ms: 0, memory_bytes: 0, output_bytes: 1_000)
      expect(metrics.output_within?(limits)).to be true
    end

    it "returns false when output exceeds limit" do
      metrics = described_class.new(duration_ms: 0, memory_bytes: 0, output_bytes: 100_000)
      expect(metrics.output_within?(limits)).to be false
    end
  end

  describe "#duration_seconds" do
    it "converts milliseconds to seconds" do
      metrics = described_class.new(duration_ms: 1500, memory_bytes: 0, output_bytes: 0)
      expect(metrics.duration_seconds).to eq(1.5)
    end

    it "handles zero duration" do
      expect(described_class.zero.duration_seconds).to eq(0.0)
    end

    it "handles small durations" do
      metrics = described_class.new(duration_ms: 1, memory_bytes: 0, output_bytes: 0)
      expect(metrics.duration_seconds).to eq(0.001)
    end

    it "handles large durations" do
      metrics = described_class.new(duration_ms: 3_600_000, memory_bytes: 0, output_bytes: 0)
      expect(metrics.duration_seconds).to eq(3600.0)
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      hash = instance.to_h
      expect(hash.keys).to contain_exactly(:duration_ms, :memory_bytes, :output_bytes)
    end

    it "includes correct values" do
      hash = instance.to_h
      expect(hash[:duration_ms]).to eq(1000)
      expect(hash[:memory_bytes]).to eq(1024)
      expect(hash[:output_bytes]).to eq(512)
    end
  end

  describe "pattern matching" do
    it "matches on duration_ms" do
      result = case instance
               in duration_ms: 1000
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end

    it "matches on multiple fields" do
      result = case instance
               in memory_bytes: 1024, output_bytes: 512
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end
  end

  describe "edge cases" do
    it "accepts zero for all fields" do
      metrics = described_class.zero
      expect(metrics.duration_ms).to eq(0)
      expect(metrics.memory_bytes).to eq(0)
      expect(metrics.output_bytes).to eq(0)
    end

    it "accepts very large values" do
      metrics = described_class.new(
        duration_ms: 2**62,
        memory_bytes: 2**62,
        output_bytes: 2**62
      )
      expect(metrics.duration_ms).to eq(2**62)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(instance).to be_frozen
    end

    it "#with returns new instance" do
      updated = instance.with(duration_ms: 2000)
      expect(updated).to be_frozen
      expect(updated.duration_ms).to eq(2000)
      expect(instance.duration_ms).to eq(1000)
    end
  end
end
