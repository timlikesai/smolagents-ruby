require "spec_helper"

RSpec.describe Smolagents::Types::CompressionMetrics do
  describe ".empty" do
    it "has zero compressions_total" do
      metrics = described_class.empty

      expect(metrics.compressions_total).to eq(0)
    end

    it "has zero steps_compressed" do
      metrics = described_class.empty

      expect(metrics.steps_compressed).to eq(0)
    end

    it "has zero tokens_saved" do
      metrics = described_class.empty

      expect(metrics.tokens_saved).to eq(0)
    end

    it "has nil last_compression_at" do
      metrics = described_class.empty

      expect(metrics.last_compression_at).to be_nil
    end

    it "is frozen" do
      metrics = described_class.empty

      expect(metrics).to be_frozen
    end
  end

  describe "#record_compression" do
    it "increments compressions_total" do
      metrics = described_class.empty
      updated = metrics.record_compression(steps: 5, tokens_saved: 100)

      expect(updated.compressions_total).to eq(1)
    end

    it "adds steps_compressed" do
      metrics = described_class.empty
      updated = metrics.record_compression(steps: 5, tokens_saved: 100)

      expect(updated.steps_compressed).to eq(5)
    end

    it "accumulates steps_compressed over multiple calls" do
      metrics = described_class.empty
                               .record_compression(steps: 3, tokens_saved: 50)
                               .record_compression(steps: 4, tokens_saved: 80)

      expect(metrics.steps_compressed).to eq(7)
    end

    it "adds tokens_saved" do
      metrics = described_class.empty
      updated = metrics.record_compression(steps: 5, tokens_saved: 100)

      expect(updated.tokens_saved).to eq(100)
    end

    it "accumulates tokens_saved over multiple calls" do
      metrics = described_class.empty
                               .record_compression(steps: 3, tokens_saved: 50)
                               .record_compression(steps: 4, tokens_saved: 80)

      expect(metrics.tokens_saved).to eq(130)
    end

    it "sets last_compression_at to current time" do
      metrics = described_class.empty
      updated = metrics.record_compression(steps: 5, tokens_saved: 100)

      expect(updated.last_compression_at).to be_within(1).of(Time.now)
    end

    it "returns new frozen instance" do
      metrics = described_class.empty
      updated = metrics.record_compression(steps: 5, tokens_saved: 100)

      expect(updated).to be_frozen
      expect(metrics.compressions_total).to eq(0)
    end

    it "does not modify original metrics" do
      original = described_class.empty
      original.record_compression(steps: 5, tokens_saved: 100)

      expect(original.compressions_total).to eq(0)
      expect(original.tokens_saved).to eq(0)
    end
  end

  describe "#any?" do
    it "returns false for empty metrics" do
      metrics = described_class.empty

      expect(metrics.any?).to be false
    end

    it "returns true after compression" do
      metrics = described_class.empty
                               .record_compression(steps: 1, tokens_saved: 10)

      expect(metrics.any?).to be true
    end
  end

  describe "pattern matching" do
    it "matches on compressions_total" do
      metrics = described_class.empty
                               .record_compression(steps: 3, tokens_saved: 100)

      matched = case metrics
                in compressions_total: 1
                  "one"
                else
                  "other"
                end

      expect(matched).to eq("one")
    end
  end
end
