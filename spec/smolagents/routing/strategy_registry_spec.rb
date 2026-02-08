require "spec_helper"

RSpec.describe Smolagents::Routing::StrategyRegistry do
  # Save and restore registry state
  around do |example|
    described_class.reset!
    example.run
    described_class.reset!
  end

  describe ".register" do
    it "registers a strategy class" do
      custom_class = Class.new do
        include Smolagents::Routing::RoutingStrategy

        def self.strategy_name = :custom
        def route(_prediction, _context) = :execute_directly
      end

      described_class.register(:custom, custom_class)

      expect(described_class.get(:custom)).to eq(custom_class)
    end

    it "accepts string names" do
      custom_class = Class.new
      described_class.register("my_strategy", custom_class)

      expect(described_class.get(:my_strategy)).to eq(custom_class)
    end
  end

  describe ".get" do
    it "returns registered strategy class" do
      expect(described_class.get(:threshold)).to eq(Smolagents::Routing::Strategies::Threshold)
    end

    it "returns nil for unknown strategy" do
      expect(described_class.get(:unknown)).to be_nil
    end

    it "accepts string names" do
      expect(described_class.get("threshold")).to eq(Smolagents::Routing::Strategies::Threshold)
    end
  end

  describe ".build" do
    it "builds a strategy instance" do
      strategy = described_class.build(:threshold)

      expect(strategy).to be_a(Smolagents::Routing::Strategies::Threshold)
    end

    it "passes options to constructor" do
      strategy = described_class.build(:threshold, high_threshold: 0.9, low_threshold: 0.6)

      expect(strategy.high_threshold).to eq(0.9)
      expect(strategy.low_threshold).to eq(0.6)
    end

    it "raises ArgumentError for unknown strategy" do
      expect { described_class.build(:unknown) }.to raise_error(ArgumentError, /Unknown strategy: unknown/)
    end

    it "builds cost_aware strategy" do
      strategy = described_class.build(:cost_aware)

      expect(strategy).to be_a(Smolagents::Routing::Strategies::CostAware)
    end

    it "builds composite strategy" do
      s1 = Smolagents::Routing::Strategies::Threshold.new
      strategy = described_class.build(:composite, strategies: [s1], combine_with: :vote)

      expect(strategy).to be_a(Smolagents::Routing::Strategies::Composite)
      expect(strategy.combine_method).to eq(:vote)
    end
  end

  describe ".all" do
    it "returns all registered strategy names" do
      names = described_class.all

      expect(names).to include(:threshold)
      expect(names).to include(:cost_aware)
      expect(names).to include(:composite)
    end

    it "includes custom strategies after registration" do
      custom_class = Class.new
      described_class.register(:my_custom, custom_class)

      expect(described_class.all).to include(:my_custom)
    end
  end

  describe ".reset!" do
    it "re-registers built-in strategies" do
      # Add a custom strategy
      described_class.register(:temp, Class.new)
      expect(described_class.get(:temp)).not_to be_nil

      # Reset
      described_class.reset!

      # Custom gone, built-ins remain
      expect(described_class.get(:temp)).to be_nil
      expect(described_class.get(:threshold)).not_to be_nil
    end
  end

  describe "built-in registrations" do
    it "has threshold registered" do
      expect(described_class.get(:threshold)).to eq(Smolagents::Routing::Strategies::Threshold)
    end

    it "has cost_aware registered" do
      expect(described_class.get(:cost_aware)).to eq(Smolagents::Routing::Strategies::CostAware)
    end

    it "has composite registered" do
      expect(described_class.get(:composite)).to eq(Smolagents::Routing::Strategies::Composite)
    end
  end
end
