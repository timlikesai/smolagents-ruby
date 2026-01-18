RSpec.describe Smolagents::Types::MemoryConfig do
  describe ".default" do
    subject(:config) { described_class.default }

    it "has no budget" do
      expect(config.budget).to be_nil
    end

    it "uses full strategy" do
      expect(config.strategy).to eq(:full)
    end

    it "preserves 3 recent steps" do
      expect(config.preserve_recent).to eq(3)
    end

    it "has default mask placeholder" do
      expect(config.mask_placeholder).to eq("[Previous observation truncated]")
    end
  end

  describe ".masked" do
    subject(:config) { described_class.masked(budget: 8000, preserve_recent: 5) }

    it "sets the budget" do
      expect(config.budget).to eq(8000)
    end

    it "uses mask strategy" do
      expect(config.strategy).to eq(:mask)
    end

    it "sets preserve_recent" do
      expect(config.preserve_recent).to eq(5)
    end

    it "uses default preserve_recent when not specified" do
      config = described_class.masked(budget: 4000)
      expect(config.preserve_recent).to eq(5)
    end
  end

  describe "#budget?" do
    it "returns false when budget is nil" do
      config = described_class.default
      expect(config.budget?).to be false
    end

    it "returns true when budget is set" do
      config = described_class.masked(budget: 8000)
      expect(config.budget?).to be true
    end
  end

  describe "#full?" do
    it "returns true for full strategy" do
      config = described_class.default
      expect(config.full?).to be true
    end

    it "returns false for mask strategy" do
      config = described_class.masked(budget: 8000)
      expect(config.full?).to be false
    end
  end

  describe "#mask?" do
    it "returns true for mask strategy" do
      config = described_class.masked(budget: 8000)
      expect(config.mask?).to be true
    end

    it "returns false for full strategy" do
      config = described_class.default
      expect(config.mask?).to be false
    end
  end

  describe "#summarize?" do
    it "returns true for summarize strategy" do
      config = described_class.new(budget: 8000, strategy: :summarize, preserve_recent: 3,
                                   mask_placeholder: "[truncated]")
      expect(config.summarize?).to be true
    end

    it "returns false for other strategies" do
      config = described_class.default
      expect(config.summarize?).to be false
    end
  end

  describe "#hybrid?" do
    it "returns true for hybrid strategy" do
      config = described_class.new(budget: 8000, strategy: :hybrid, preserve_recent: 3,
                                   mask_placeholder: "[truncated]")
      expect(config.hybrid?).to be true
    end

    it "returns false for other strategies" do
      config = described_class.default
      expect(config.hybrid?).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      config = described_class.default
      expect(config).to be_frozen
    end
  end
end
