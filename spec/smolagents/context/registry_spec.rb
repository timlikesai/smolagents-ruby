require "spec_helper"
require "smolagents/context/registry"
require "smolagents/context/provider"

RSpec.describe Smolagents::Context::Registry do
  # Test provider classes
  let(:strategic_provider) do
    Class.new do
      include Smolagents::Context::Provider

      def context_key = :strategic_test
      def context_layer = Smolagents::Context::Layer::STRATEGIC
      def context_contribution(budget:) = "strategic"
    end
  end

  let(:tactical_provider) do
    Class.new do
      include Smolagents::Context::Provider

      def context_key = :tactical_test
      def context_layer = Smolagents::Context::Layer::TACTICAL
      def context_contribution(budget:) = "tactical"
    end
  end

  let(:persistent_provider) do
    Class.new do
      include Smolagents::Context::Provider

      def context_key = :persistent_test
      def context_layer = Smolagents::Context::Layer::PERSISTENT
      def context_contribution(budget:) = "persistent"
    end
  end

  before { described_class.clear! }
  after { described_class.clear! }

  describe ".register" do
    it "registers a provider class" do
      described_class.register(:test, strategic_provider)
      expect(described_class[:test]).to eq(strategic_provider)
    end

    it "returns the registered class" do
      result = described_class.register(:test, tactical_provider)
      expect(result).to eq(tactical_provider)
    end

    it "overwrites existing registration" do
      described_class.register(:test, strategic_provider)
      described_class.register(:test, tactical_provider)
      expect(described_class[:test]).to eq(tactical_provider)
    end
  end

  describe ".[]" do
    it "returns registered provider" do
      described_class.register(:lookup_test, strategic_provider)
      expect(described_class[:lookup_test]).to eq(strategic_provider)
    end

    it "returns nil for unregistered key" do
      expect(described_class[:nonexistent]).to be_nil
    end
  end

  describe ".all" do
    it "returns empty array when no providers registered" do
      expect(described_class.all).to eq([])
    end

    it "returns all registered keys" do
      described_class.register(:one, strategic_provider)
      described_class.register(:two, tactical_provider)
      expect(described_class.all).to contain_exactly(:one, :two)
    end
  end

  describe ".providers" do
    it "returns empty array when no providers registered" do
      expect(described_class.providers).to eq([])
    end

    it "returns all registered classes" do
      described_class.register(:one, strategic_provider)
      described_class.register(:two, tactical_provider)
      expect(described_class.providers).to contain_exactly(strategic_provider, tactical_provider)
    end
  end

  describe ".registered?" do
    it "returns false for unregistered key" do
      expect(described_class.registered?(:unknown)).to be false
    end

    it "returns true for registered key" do
      described_class.register(:known, strategic_provider)
      expect(described_class.registered?(:known)).to be true
    end
  end

  describe ".for_layer" do
    before do
      described_class.register(:strategic, strategic_provider)
      described_class.register(:tactical, tactical_provider)
      described_class.register(:persistent, persistent_provider)
    end

    it "returns providers for STRATEGIC layer" do
      result = described_class.for_layer(Smolagents::Context::Layer::STRATEGIC)
      expect(result).to eq([strategic_provider])
    end

    it "returns providers for TACTICAL layer" do
      result = described_class.for_layer(Smolagents::Context::Layer::TACTICAL)
      expect(result).to eq([tactical_provider])
    end

    it "returns providers for PERSISTENT layer" do
      result = described_class.for_layer(Smolagents::Context::Layer::PERSISTENT)
      expect(result).to eq([persistent_provider])
    end

    it "returns empty array for layer with no providers" do
      result = described_class.for_layer(Smolagents::Context::Layer::SYSTEM)
      expect(result).to eq([])
    end

    it "returns multiple providers for same layer" do
      another_strategic = Class.new do
        include Smolagents::Context::Provider

        def context_key = :another
        def context_layer = Smolagents::Context::Layer::STRATEGIC
        def context_contribution(budget:) = "another"
      end
      described_class.register(:another_strategic, another_strategic)

      result = described_class.for_layer(Smolagents::Context::Layer::STRATEGIC)
      expect(result).to contain_exactly(strategic_provider, another_strategic)
    end
  end

  describe ".by_layer" do
    before do
      described_class.register(:strategic, strategic_provider)
      described_class.register(:tactical, tactical_provider)
    end

    it "returns hash keyed by layer" do
      result = described_class.by_layer
      expect(result.keys).to eq(Smolagents::Context::Layer::ALL)
    end

    it "groups providers correctly" do
      result = described_class.by_layer
      expect(result[Smolagents::Context::Layer::STRATEGIC]).to eq([strategic_provider])
      expect(result[Smolagents::Context::Layer::TACTICAL]).to eq([tactical_provider])
    end

    it "includes empty arrays for layers without providers" do
      result = described_class.by_layer
      expect(result[Smolagents::Context::Layer::SYSTEM]).to eq([])
      expect(result[Smolagents::Context::Layer::HISTORY]).to eq([])
    end
  end

  describe ".clear!" do
    it "removes all registered providers" do
      described_class.register(:test, strategic_provider)
      described_class.clear!
      expect(described_class.all).to be_empty
    end
  end

  describe ".size" do
    it "returns 0 when empty" do
      expect(described_class.size).to eq(0)
    end

    it "returns count of registered providers" do
      described_class.register(:one, strategic_provider)
      described_class.register(:two, tactical_provider)
      expect(described_class.size).to eq(2)
    end
  end
end
