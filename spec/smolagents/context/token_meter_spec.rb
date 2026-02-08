require "spec_helper"
require "smolagents/context/token_meter"

RSpec.describe Smolagents::Context::TokenMeter do
  describe ".new" do
    it "creates meter with budget and zero used" do
      meter = described_class.new(budget: 1000)
      expect(meter.budget).to eq(1000)
      expect(meter.used).to eq(0)
    end

    it "uses default thresholds" do
      meter = described_class.new(budget: 1000)
      expect(meter.warn_at).to eq(0.8)
      expect(meter.fail_at).to eq(1.0)
    end

    it "accepts custom thresholds" do
      meter = described_class.new(budget: 1000, warn_at: 0.9, fail_at: 0.95)
      expect(meter.warn_at).to eq(0.9)
      expect(meter.fail_at).to eq(0.95)
    end
  end

  describe "#add" do
    let(:meter) { described_class.new(budget: 1000) }

    it "returns new meter with added tokens" do
      updated = meter.add(500)
      expect(updated.used).to eq(500)
    end

    it "preserves original meter (immutable)" do
      meter.add(500)
      expect(meter.used).to eq(0)
    end

    it "can be chained" do
      result = meter.add(100).add(200).add(300)
      expect(result.used).to eq(600)
    end
  end

  describe "#remaining" do
    it "returns difference between budget and used" do
      meter = described_class.new(budget: 1000).add(300)
      expect(meter.remaining).to eq(700)
    end

    it "can be negative when over budget" do
      meter = described_class.new(budget: 100).add(150)
      expect(meter.remaining).to eq(-50)
    end
  end

  describe "#usage_percent" do
    it "returns usage as fraction" do
      meter = described_class.new(budget: 1000).add(500)
      expect(meter.usage_percent).to eq(0.5)
    end

    it "returns 0.0 for empty meter" do
      meter = described_class.new(budget: 1000)
      expect(meter.usage_percent).to eq(0.0)
    end

    it "can exceed 1.0 when over budget" do
      meter = described_class.new(budget: 100).add(150)
      expect(meter.usage_percent).to eq(1.5)
    end

    it "handles zero budget gracefully" do
      meter = described_class.new(budget: 0)
      expect(meter.usage_percent).to eq(0.0)
    end
  end

  describe "#over_budget?" do
    it "returns false when under budget" do
      meter = described_class.new(budget: 1000).add(500)
      expect(meter.over_budget?).to be false
    end

    it "returns false when exactly at budget" do
      meter = described_class.new(budget: 1000).add(1000)
      expect(meter.over_budget?).to be false
    end

    it "returns true when over budget" do
      meter = described_class.new(budget: 1000).add(1001)
      expect(meter.over_budget?).to be true
    end
  end

  describe "#warning?" do
    it "returns false when below threshold" do
      meter = described_class.new(budget: 1000).add(700)
      expect(meter.warning?).to be false
    end

    it "returns true at exactly threshold" do
      meter = described_class.new(budget: 1000).add(800)
      expect(meter.warning?).to be true
    end

    it "returns true above threshold" do
      meter = described_class.new(budget: 1000).add(900)
      expect(meter.warning?).to be true
    end

    it "respects custom warn_at threshold" do
      meter = described_class.new(budget: 1000, warn_at: 0.5).add(500)
      expect(meter.warning?).to be true
    end
  end

  describe "#headroom" do
    it "returns remaining when positive" do
      meter = described_class.new(budget: 1000).add(300)
      expect(meter.headroom).to eq(700)
    end

    it "returns zero when exactly at budget" do
      meter = described_class.new(budget: 1000).add(1000)
      expect(meter.headroom).to eq(0)
    end

    it "returns zero when over budget (never negative)" do
      meter = described_class.new(budget: 100).add(150)
      expect(meter.headroom).to eq(0)
    end
  end

  describe "#can_fit?" do
    let(:meter) { described_class.new(budget: 1000).add(800) }

    it "returns true when tokens fit" do
      expect(meter.can_fit?(100)).to be true
    end

    it "returns true at exact remaining" do
      expect(meter.can_fit?(200)).to be true
    end

    it "returns false when tokens exceed remaining" do
      expect(meter.can_fit?(201)).to be false
    end

    it "handles zero tokens" do
      expect(meter.can_fit?(0)).to be true
    end
  end

  describe "edge cases" do
    it "handles zero budget" do
      meter = described_class.new(budget: 0)
      expect(meter.remaining).to eq(0)
      expect(meter.headroom).to eq(0)
      expect(meter.can_fit?(0)).to be true
      expect(meter.can_fit?(1)).to be false
    end

    it "handles exact budget usage" do
      meter = described_class.new(budget: 100).add(100)
      expect(meter.remaining).to eq(0)
      expect(meter.over_budget?).to be false
      expect(meter.usage_percent).to eq(1.0)
    end
  end
end
