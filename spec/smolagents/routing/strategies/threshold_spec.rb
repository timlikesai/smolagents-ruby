require "spec_helper"

RSpec.describe Smolagents::Routing::Strategies::Threshold do
  describe ".strategy_name" do
    it "returns :threshold" do
      expect(described_class.strategy_name).to eq(:threshold)
    end
  end

  describe "#initialize" do
    it "uses default thresholds" do
      strategy = described_class.new

      expect(strategy.high_threshold).to eq(0.8)
      expect(strategy.low_threshold).to eq(0.5)
    end

    it "accepts custom thresholds" do
      strategy = described_class.new(high_threshold: 0.9, low_threshold: 0.6)

      expect(strategy.high_threshold).to eq(0.9)
      expect(strategy.low_threshold).to eq(0.6)
    end
  end

  describe "#route" do
    let(:strategy) { described_class.new(high_threshold: 0.8, low_threshold: 0.5) }

    def prediction(confidence:)
      double("SpeculativeToolCall", confidence:)
    end

    context "with high confidence" do
      it "returns :execute_directly for confidence at threshold" do
        result = strategy.route(prediction(confidence: 0.8), {})

        expect(result).to eq(:execute_directly)
      end

      it "returns :execute_directly for confidence above threshold" do
        result = strategy.route(prediction(confidence: 0.95), {})

        expect(result).to eq(:execute_directly)
      end
    end

    context "with medium confidence" do
      it "returns :validate_with_primary for confidence at low threshold" do
        result = strategy.route(prediction(confidence: 0.5), {})

        expect(result).to eq(:validate_with_primary)
      end

      it "returns :validate_with_primary for confidence between thresholds" do
        result = strategy.route(prediction(confidence: 0.65), {})

        expect(result).to eq(:validate_with_primary)
      end

      it "returns :validate_with_primary just below high threshold" do
        result = strategy.route(prediction(confidence: 0.79), {})

        expect(result).to eq(:validate_with_primary)
      end
    end

    context "with low confidence" do
      it "returns :delegate_to_primary for confidence below low threshold" do
        result = strategy.route(prediction(confidence: 0.49), {})

        expect(result).to eq(:delegate_to_primary)
      end

      it "returns :delegate_to_primary for very low confidence" do
        result = strategy.route(prediction(confidence: 0.1), {})

        expect(result).to eq(:delegate_to_primary)
      end

      it "returns :delegate_to_primary for zero confidence" do
        result = strategy.route(prediction(confidence: 0.0), {})

        expect(result).to eq(:delegate_to_primary)
      end
    end

    context "with aggressive thresholds" do
      let(:aggressive) { described_class.new(high_threshold: 0.6, low_threshold: 0.3) }

      it "executes directly at lower confidence" do
        result = aggressive.route(prediction(confidence: 0.65), {})

        expect(result).to eq(:execute_directly)
      end

      it "validates at lower threshold" do
        result = aggressive.route(prediction(confidence: 0.35), {})

        expect(result).to eq(:validate_with_primary)
      end
    end

    context "with conservative thresholds" do
      let(:conservative) { described_class.new(high_threshold: 0.95, low_threshold: 0.8) }

      it "requires higher confidence for direct execution" do
        result = conservative.route(prediction(confidence: 0.9), {})

        expect(result).to eq(:validate_with_primary)
      end

      it "delegates earlier" do
        result = conservative.route(prediction(confidence: 0.75), {})

        expect(result).to eq(:delegate_to_primary)
      end
    end
  end

  describe "#applicable?" do
    it "returns true for any context" do
      strategy = described_class.new

      expect(strategy.applicable?({})).to be true
      expect(strategy.applicable?(foo: :bar)).to be true
    end
  end
end
