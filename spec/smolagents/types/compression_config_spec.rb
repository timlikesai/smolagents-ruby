require "spec_helper"

RSpec.describe Smolagents::Types::CompressionConfig do
  describe ".default" do
    it "uses model_based strategy" do
      config = described_class.default

      expect(config.strategy).to eq(:model_based)
    end

    it "sets threshold to 0.75" do
      config = described_class.default

      expect(config.threshold).to eq(0.75)
    end

    it "preserves 3 recent steps" do
      config = described_class.default

      expect(config.preserve_recent).to eq(3)
    end

    it "allows 500 max summary tokens" do
      config = described_class.default

      expect(config.max_summary_tokens).to eq(500)
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".disabled" do
    it "uses none strategy" do
      config = described_class.disabled

      expect(config.strategy).to eq(:none)
    end

    it "sets threshold to 1.0" do
      config = described_class.disabled

      expect(config.threshold).to eq(1.0)
    end

    it "preserves 0 recent steps" do
      config = described_class.disabled

      expect(config.preserve_recent).to eq(0)
    end

    it "allows 0 max summary tokens" do
      config = described_class.disabled

      expect(config.max_summary_tokens).to eq(0)
    end

    it "is frozen" do
      config = described_class.disabled

      expect(config).to be_frozen
    end
  end

  describe "#enabled?" do
    it "returns true for model_based strategy" do
      config = described_class.default

      expect(config.enabled?).to be true
    end

    it "returns true for keyword strategy" do
      config = described_class.new(
        strategy: :keyword,
        threshold: 0.75,
        preserve_recent: 3,
        max_summary_tokens: 500
      )

      expect(config.enabled?).to be true
    end

    it "returns false for none strategy" do
      config = described_class.disabled

      expect(config.enabled?).to be false
    end
  end

  describe "#model_based?" do
    it "returns true for model_based strategy" do
      config = described_class.default

      expect(config.model_based?).to be true
    end

    it "returns false for keyword strategy" do
      config = described_class.new(
        strategy: :keyword,
        threshold: 0.75,
        preserve_recent: 3,
        max_summary_tokens: 500
      )

      expect(config.model_based?).to be false
    end

    it "returns false for none strategy" do
      config = described_class.disabled

      expect(config.model_based?).to be false
    end
  end

  describe "#keyword_based?" do
    it "returns true for keyword strategy" do
      config = described_class.new(
        strategy: :keyword,
        threshold: 0.75,
        preserve_recent: 3,
        max_summary_tokens: 500
      )

      expect(config.keyword_based?).to be true
    end

    it "returns false for model_based strategy" do
      config = described_class.default

      expect(config.keyword_based?).to be false
    end

    it "returns false for none strategy" do
      config = described_class.disabled

      expect(config.keyword_based?).to be false
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      config = described_class.new(
        strategy: :model_based,
        threshold: 0.8,
        preserve_recent: 5,
        max_summary_tokens: 300
      )

      expect(config).to be_frozen
    end

    it "with method returns new frozen instance" do
      config = described_class.default
      updated = config.with(threshold: 0.9)

      expect(updated).to be_frozen
      expect(config.threshold).to eq(0.75)
      expect(updated.threshold).to eq(0.9)
    end
  end

  describe "pattern matching" do
    it "matches on strategy" do
      config = described_class.default

      matched = case config
                in strategy: :model_based
                  "model"
                else
                  "other"
                end

      expect(matched).to eq("model")
    end

    it "matches on disabled strategy" do
      config = described_class.disabled

      matched = case config
                in strategy: :none
                  "disabled"
                else
                  "enabled"
                end

      expect(matched).to eq("disabled")
    end
  end
end
