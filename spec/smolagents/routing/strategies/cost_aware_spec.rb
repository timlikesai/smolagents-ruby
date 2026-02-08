require "spec_helper"

RSpec.describe Smolagents::Routing::Strategies::CostAware do
  describe ".strategy_name" do
    it "returns :cost_aware" do
      expect(described_class.strategy_name).to eq(:cost_aware)
    end
  end

  describe "#initialize" do
    it "uses default Threshold fallback" do
      strategy = described_class.new

      expect(strategy.fallback_strategy).to be_a(Smolagents::Routing::Strategies::Threshold)
    end

    it "accepts custom fallback strategy" do
      custom = Smolagents::Routing::Strategies::Threshold.new(high_threshold: 0.9)
      strategy = described_class.new(fallback_strategy: custom)

      expect(strategy.fallback_strategy).to eq(custom)
    end
  end

  describe "#route" do
    let(:strategy) { described_class.new }

    def prediction(confidence:, arg_count: 1)
      args = (1..arg_count).map { |i| ["arg#{i}", "val#{i}"] }.to_h
      double("SpeculativeToolCall", confidence:, arguments: args)
    end

    context "when over budget" do
      it "delegates to primary when estimated cost exceeds budget" do
        result = strategy.route(
          prediction(confidence: 0.95),
          remaining_budget: 50, estimated_cost: 200
        )

        expect(result).to eq(:delegate_to_primary)
      end

      it "delegates even with high confidence when over budget" do
        result = strategy.route(
          prediction(confidence: 1.0),
          remaining_budget: 10, estimated_cost: 100
        )

        expect(result).to eq(:delegate_to_primary)
      end
    end

    context "when within budget" do
      it "falls back to threshold strategy for high confidence" do
        result = strategy.route(
          prediction(confidence: 0.85),
          remaining_budget: 500, estimated_cost: 100
        )

        expect(result).to eq(:execute_directly)
      end

      it "falls back to threshold strategy for medium confidence" do
        result = strategy.route(
          prediction(confidence: 0.6),
          remaining_budget: 500, estimated_cost: 100
        )

        expect(result).to eq(:validate_with_primary)
      end

      it "falls back to threshold strategy for low confidence" do
        result = strategy.route(
          prediction(confidence: 0.3),
          remaining_budget: 500, estimated_cost: 100
        )

        expect(result).to eq(:delegate_to_primary)
      end
    end

    context "when no budget info" do
      it "uses fallback strategy when no remaining_budget" do
        result = strategy.route(
          prediction(confidence: 0.85),
          {}
        )

        expect(result).to eq(:execute_directly)
      end

      it "uses fallback strategy when no estimated_cost" do
        result = strategy.route(
          prediction(confidence: 0.85),
          remaining_budget: 500
        )

        expect(result).to eq(:execute_directly)
      end
    end

    context "cost estimation" do
      it "estimates higher cost for complex tools" do
        complex = prediction(confidence: 0.9, arg_count: 5)
        result = strategy.route(complex, remaining_budget: 150)

        # 5 args > 2, so estimate is 200, which exceeds 150
        expect(result).to eq(:delegate_to_primary)
      end

      it "estimates lower cost for simple tools" do
        simple = prediction(confidence: 0.9, arg_count: 1)
        result = strategy.route(simple, remaining_budget: 150)

        # 1 arg <= 2, so estimate is 100, which is within 150
        expect(result).to eq(:execute_directly)
      end
    end
  end

  describe "#applicable?" do
    let(:strategy) { described_class.new }

    it "returns true when remaining_budget is present" do
      expect(strategy.applicable?(remaining_budget: 100)).to be true
    end

    it "returns false when remaining_budget is absent" do
      expect(strategy.applicable?({})).to be false
      expect(strategy.applicable?(estimated_cost: 100)).to be false
    end
  end
end
