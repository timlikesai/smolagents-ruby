require "spec_helper"

RSpec.describe Smolagents::Routing::RoutingStrategy do
  describe "DECISIONS constant" do
    it "defines the three valid routing decisions" do
      expect(described_class::DECISIONS).to eq(%i[execute_directly validate_with_primary delegate_to_primary])
    end

    it "is frozen" do
      expect(described_class::DECISIONS).to be_frozen
    end
  end

  describe "interface contract" do
    let(:strategy_class) do
      Class.new do
        include Smolagents::Routing::RoutingStrategy
      end
    end

    let(:strategy) { strategy_class.new }
    let(:prediction) { double("SpeculativeToolCall", confidence: 0.8) }

    describe ".strategy_name" do
      it "raises NotImplementedError by default" do
        expect { strategy_class.strategy_name }.to raise_error(NotImplementedError)
      end
    end

    describe "#route" do
      it "raises NotImplementedError by default" do
        expect { strategy.route(prediction, {}) }.to raise_error(NotImplementedError)
      end
    end

    describe "#applicable?" do
      it "returns true by default" do
        expect(strategy.applicable?({})).to be true
      end
    end
  end

  describe "implemented strategy" do
    let(:strategy_class) do
      Class.new do
        include Smolagents::Routing::RoutingStrategy

        def self.strategy_name = :test_strategy

        def route(prediction, _context)
          prediction.confidence >= 0.5 ? :execute_directly : :delegate_to_primary
        end

        def applicable?(context)
          context[:enabled] == true
        end
      end
    end

    let(:strategy) { strategy_class.new }

    it "returns custom strategy_name" do
      expect(strategy_class.strategy_name).to eq(:test_strategy)
    end

    it "implements route with custom logic" do
      high = double("SpeculativeToolCall", confidence: 0.8)
      low = double("SpeculativeToolCall", confidence: 0.3)

      expect(strategy.route(high, {})).to eq(:execute_directly)
      expect(strategy.route(low, {})).to eq(:delegate_to_primary)
    end

    it "implements applicable? with custom logic" do
      expect(strategy.applicable?(enabled: true)).to be true
      expect(strategy.applicable?(enabled: false)).to be false
    end
  end
end
