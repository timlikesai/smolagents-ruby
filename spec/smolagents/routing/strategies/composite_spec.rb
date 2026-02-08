require "spec_helper"

RSpec.describe Smolagents::Routing::Strategies::Composite do
  describe ".strategy_name" do
    it "returns :composite" do
      expect(described_class.strategy_name).to eq(:composite)
    end
  end

  describe "#initialize" do
    it "accepts strategies array" do
      s1 = Smolagents::Routing::Strategies::Threshold.new
      s2 = Smolagents::Routing::Strategies::Threshold.new(high_threshold: 0.9)
      composite = described_class.new(strategies: [s1, s2])

      expect(composite.strategies).to eq([s1, s2])
    end

    it "defaults to :all combine method" do
      composite = described_class.new(strategies: [])

      expect(composite.combine_method).to eq(:all)
    end

    it "accepts custom combine method" do
      composite = described_class.new(strategies: [], combine_with: :vote)

      expect(composite.combine_method).to eq(:vote)
    end
  end

  describe "#route" do
    def prediction(confidence:)
      double("SpeculativeToolCall", confidence:)
    end

    # Helper strategies with predictable behavior
    let(:always_execute) do
      strategy = instance_double("RoutingStrategy")
      allow(strategy).to receive(:route).and_return(:execute_directly)
      strategy
    end

    let(:always_validate) do
      strategy = instance_double("RoutingStrategy")
      allow(strategy).to receive(:route).and_return(:validate_with_primary)
      strategy
    end

    let(:always_delegate) do
      strategy = instance_double("RoutingStrategy")
      allow(strategy).to receive(:route).and_return(:delegate_to_primary)
      strategy
    end

    let(:pred) { prediction(confidence: 0.7) }
    let(:context) { {} }

    describe "combine_with: :all" do
      it "returns :execute_directly when all strategies agree" do
        composite = described_class.new(
          strategies: [always_execute, always_execute, always_execute],
          combine_with: :all
        )

        expect(composite.route(pred, context)).to eq(:execute_directly)
      end

      it "returns :validate_with_primary when any strategy disagrees" do
        composite = described_class.new(
          strategies: [always_execute, always_validate, always_execute],
          combine_with: :all
        )

        expect(composite.route(pred, context)).to eq(:validate_with_primary)
      end

      it "returns :validate_with_primary when all strategies validate" do
        composite = described_class.new(
          strategies: [always_validate, always_validate],
          combine_with: :all
        )

        expect(composite.route(pred, context)).to eq(:validate_with_primary)
      end
    end

    describe "combine_with: :any" do
      it "returns :execute_directly when any strategy votes execute" do
        composite = described_class.new(
          strategies: [always_validate, always_execute, always_delegate],
          combine_with: :any
        )

        expect(composite.route(pred, context)).to eq(:execute_directly)
      end

      it "returns :validate_with_primary when no strategy votes execute" do
        composite = described_class.new(
          strategies: [always_validate, always_delegate, always_validate],
          combine_with: :any
        )

        expect(composite.route(pred, context)).to eq(:validate_with_primary)
      end
    end

    describe "combine_with: :vote" do
      it "returns :execute_directly when majority votes execute" do
        composite = described_class.new(
          strategies: [always_execute, always_execute, always_validate],
          combine_with: :vote
        )

        expect(composite.route(pred, context)).to eq(:execute_directly)
      end

      it "returns :validate_with_primary when majority does not vote execute" do
        composite = described_class.new(
          strategies: [always_execute, always_validate, always_delegate],
          combine_with: :vote
        )

        expect(composite.route(pred, context)).to eq(:validate_with_primary)
      end

      it "returns :validate_with_primary on tie (2 execute, 2 not)" do
        composite = described_class.new(
          strategies: [always_execute, always_execute, always_validate, always_delegate],
          combine_with: :vote
        )

        expect(composite.route(pred, context)).to eq(:validate_with_primary)
      end

      it "returns :execute_directly when clear majority" do
        composite = described_class.new(
          strategies: [always_execute, always_execute, always_execute, always_validate],
          combine_with: :vote
        )

        expect(composite.route(pred, context)).to eq(:execute_directly)
      end
    end

    describe "unknown combine method" do
      it "raises ArgumentError" do
        composite = described_class.new(strategies: [always_execute], combine_with: :unknown)

        expect { composite.route(pred, context) }.to raise_error(ArgumentError, /Unknown combine method/)
      end
    end

    describe "integration with real strategies" do
      it "combines threshold strategies with different settings" do
        conservative = Smolagents::Routing::Strategies::Threshold.new(high_threshold: 0.9)
        aggressive = Smolagents::Routing::Strategies::Threshold.new(high_threshold: 0.6)

        composite = described_class.new(
          strategies: [conservative, aggressive],
          combine_with: :all
        )

        # 0.8 passes aggressive (>= 0.6) but fails conservative (< 0.9)
        medium = prediction(confidence: 0.8)
        expect(composite.route(medium, {})).to eq(:validate_with_primary)

        # 0.95 passes both
        high = prediction(confidence: 0.95)
        expect(composite.route(high, {})).to eq(:execute_directly)
      end
    end
  end
end
