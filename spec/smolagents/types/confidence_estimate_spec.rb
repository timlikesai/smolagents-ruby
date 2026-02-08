require "smolagents"

RSpec.describe Smolagents::Types::ConfidenceEstimate do
  describe ".syntactic_only" do
    it "creates estimate with only syntactic score" do
      estimate = described_class.syntactic_only(0.85)

      expect(estimate.syntactic).to eq(0.85)
      expect(estimate.semantic).to be_nil
      expect(estimate.blended).to eq(0.85)
      expect(estimate.factors).to eq({})
    end

    it "accepts factors hash" do
      estimate = described_class.syntactic_only(0.9, factors: { tool_exists: true })

      expect(estimate.factors).to eq({ tool_exists: true })
    end

    it "uses syntactic as blended score" do
      estimate = described_class.syntactic_only(0.7)

      expect(estimate.blended).to eq(estimate.syntactic)
    end
  end

  describe ".with_semantic" do
    it "creates estimate with both syntactic and semantic scores" do
      estimate = described_class.with_semantic(syntactic: 0.9, semantic: 0.7)

      expect(estimate.syntactic).to eq(0.9)
      expect(estimate.semantic).to eq(0.7)
    end

    it "blends scores with default 30% semantic weight" do
      # blended = 0.7 * 0.9 + 0.3 * 0.7 = 0.63 + 0.21 = 0.84
      estimate = described_class.with_semantic(syntactic: 0.9, semantic: 0.7)

      expect(estimate.blended).to be_within(0.001).of(0.84)
    end

    it "accepts custom weight" do
      # blended = 0.5 * 0.8 + 0.5 * 0.6 = 0.4 + 0.3 = 0.7
      estimate = described_class.with_semantic(syntactic: 0.8, semantic: 0.6, weight: 0.5)

      expect(estimate.blended).to be_within(0.001).of(0.7)
    end

    it "records weights in factors" do
      estimate = described_class.with_semantic(syntactic: 0.9, semantic: 0.7, weight: 0.4)

      expect(estimate.factors[:syntactic_weight]).to eq(0.6)
      expect(estimate.factors[:semantic_weight]).to eq(0.4)
    end

    it "clamps blended score to 0.0-1.0" do
      estimate = described_class.with_semantic(syntactic: 1.5, semantic: 1.2)

      expect(estimate.blended).to eq(1.0)
    end
  end

  describe "#high_confidence?" do
    it "returns true when blended >= threshold" do
      estimate = described_class.syntactic_only(0.85)

      expect(estimate.high_confidence?).to be true
    end

    it "returns false when blended < threshold" do
      estimate = described_class.syntactic_only(0.75)

      expect(estimate.high_confidence?).to be false
    end

    it "accepts custom threshold" do
      estimate = described_class.syntactic_only(0.65)

      expect(estimate.high_confidence?(threshold: 0.6)).to be true
      expect(estimate.high_confidence?(threshold: 0.7)).to be false
    end
  end

  describe "#low_confidence?" do
    it "returns true when blended < threshold" do
      estimate = described_class.syntactic_only(0.3)

      expect(estimate.low_confidence?).to be true
    end

    it "returns false when blended >= threshold" do
      estimate = described_class.syntactic_only(0.6)

      expect(estimate.low_confidence?).to be false
    end

    it "accepts custom threshold" do
      estimate = described_class.syntactic_only(0.4)

      expect(estimate.low_confidence?(threshold: 0.3)).to be false
      expect(estimate.low_confidence?(threshold: 0.5)).to be true
    end
  end

  describe "#semantic?" do
    it "returns true when semantic is present" do
      estimate = described_class.with_semantic(syntactic: 0.8, semantic: 0.7)

      expect(estimate.semantic?).to be true
    end

    it "returns false when semantic is nil" do
      estimate = described_class.syntactic_only(0.8)

      expect(estimate.semantic?).to be false
    end
  end

  describe "#confidence" do
    it "is an alias for blended" do
      estimate = described_class.syntactic_only(0.75)

      expect(estimate.confidence).to eq(estimate.blended)
    end
  end

  describe "#to_h" do
    it "returns serializable hash" do
      estimate = described_class.with_semantic(syntactic: 0.9, semantic: 0.7)
      hash = estimate.to_h

      expect(hash[:syntactic]).to eq(0.9)
      expect(hash[:semantic]).to eq(0.7)
      expect(hash[:blended]).to be_within(0.001).of(0.84)
      expect(hash[:factors]).to be_a(Hash)
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      estimate = described_class.syntactic_only(0.85, factors: { tool_exists: true })

      case estimate
      in { blended:, factors: { tool_exists: } }
        expect(blended).to eq(0.85)
        expect(tool_exists).to be true
      else
        raise "Pattern should match"
      end
    end
  end

  describe "immutability" do
    it "is frozen" do
      estimate = described_class.syntactic_only(0.8)

      expect(estimate).to be_frozen
    end
  end
end
