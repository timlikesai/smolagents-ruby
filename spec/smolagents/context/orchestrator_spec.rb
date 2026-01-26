require "spec_helper"
require "smolagents/context/orchestrator"
require "smolagents/context/provider"

RSpec.describe Smolagents::Context::Orchestrator do
  # Helper to create test providers
  def create_provider(key:, layer: nil, priority: 50, content: "content", active: true, optional: true)
    provider = Object.new
    provider.define_singleton_method(:context_key) { key }
    provider.define_singleton_method(:context_layer) { layer || Smolagents::Context::Layer::STRATEGIC }
    provider.define_singleton_method(:context_priority) { priority }
    provider.define_singleton_method(:context_contribution) { |budget:| content }
    provider.define_singleton_method(:context_active?) { active }
    provider.define_singleton_method(:context_optional?) { optional }
    provider.define_singleton_method(:context_relevance) { |task:, step:| 1.0 }
    provider
  end

  describe "#initialize" do
    it "accepts providers array" do
      provider = create_provider(key: :test)
      orchestrator = described_class.new(providers: [provider])
      expect(orchestrator.providers).to eq([provider])
    end

    it "accepts total_budget" do
      orchestrator = described_class.new(total_budget: 2000)
      expect(orchestrator.allocator.total_budget).to eq(2000)
    end

    it "defaults to empty providers" do
      orchestrator = described_class.new
      expect(orchestrator.providers).to eq([])
    end
  end

  describe "#add_provider" do
    it "adds a provider" do
      orchestrator = described_class.new
      provider = create_provider(key: :new)
      orchestrator.add_provider(provider)
      expect(orchestrator.providers).to include(provider)
    end

    it "returns self for chaining" do
      orchestrator = described_class.new
      result = orchestrator.add_provider(create_provider(key: :a))
      expect(result).to eq(orchestrator)
    end
  end

  describe "#remove_provider" do
    let(:provider) { create_provider(key: :removable) }
    let(:orchestrator) { described_class.new(providers: [provider]) }

    it "removes provider by key" do
      orchestrator.remove_provider(:removable)
      expect(orchestrator.providers).to be_empty
    end

    it "returns removed provider" do
      result = orchestrator.remove_provider(:removable)
      expect(result).to eq(provider)
    end

    it "returns nil if not found" do
      result = orchestrator.remove_provider(:nonexistent)
      expect(result).to be_nil
    end
  end

  describe "#[]" do
    let(:provider) { create_provider(key: :findme) }
    let(:orchestrator) { described_class.new(providers: [provider]) }

    it "finds provider by key" do
      expect(orchestrator[:findme]).to eq(provider)
    end

    it "returns nil for unknown key" do
      expect(orchestrator[:unknown]).to be_nil
    end
  end

  describe "#assemble" do
    context "with no providers" do
      it "returns empty result" do
        orchestrator = described_class.new
        result = orchestrator.assemble(task: "test", step: 1)
        expect(result.content).to eq("")
      end
    end

    context "with single provider" do
      it "includes provider content" do
        provider = create_provider(key: :goal, content: "Find Ruby info")
        orchestrator = described_class.new(providers: [provider])
        result = orchestrator.assemble(task: "test", step: 1)
        expect(result.content).to include("Find Ruby info")
      end
    end

    context "with multiple providers" do
      it "includes all active provider content" do
        p1 = create_provider(key: :goal, content: "Goal content")
        p2 = create_provider(key: :plan, content: "Plan content")
        orchestrator = described_class.new(providers: [p1, p2])
        result = orchestrator.assemble(task: "test", step: 1)
        expect(result.content).to include("Goal content")
        expect(result.content).to include("Plan content")
      end

      it "excludes inactive providers" do
        active = create_provider(key: :active, content: "Active", active: true)
        inactive = create_provider(key: :inactive, content: "Inactive", active: false)
        orchestrator = described_class.new(providers: [active, inactive])
        result = orchestrator.assemble(task: "test", step: 1)
        expect(result.content).to include("Active")
        expect(result.content).not_to include("Inactive")
      end
    end

    context "with different layers" do
      it "organizes content by layer" do
        persistent = create_provider(
          key: :persistent,
          layer: Smolagents::Context::Layer::PERSISTENT,
          content: "Persistent content"
        )
        strategic = create_provider(
          key: :strategic,
          layer: Smolagents::Context::Layer::STRATEGIC,
          content: "Strategic content"
        )
        orchestrator = described_class.new(providers: [persistent, strategic])
        result = orchestrator.assemble(task: "test", step: 1)

        expect(result.layers[:persistent]).to include("Persistent content")
        expect(result.layers[:strategic]).to include("Strategic content")
      end
    end

    context "with priority ordering" do
      it "orders by priority within layer" do
        low = create_provider(key: :low, priority: 30, content: "Low priority")
        high = create_provider(key: :high, priority: 80, content: "High priority")
        orchestrator = described_class.new(providers: [low, high])
        result = orchestrator.assemble(task: "test", step: 1)

        # High priority should come before low in the content
        high_pos = result.content.index("High priority")
        low_pos = result.content.index("Low priority")
        expect(high_pos).to be < low_pos
      end
    end

    context "with nil contributions" do
      it "skips providers returning nil" do
        nil_provider = Object.new
        nil_provider.define_singleton_method(:context_key) { :nil_content }
        nil_provider.define_singleton_method(:context_layer) { Smolagents::Context::Layer::STRATEGIC }
        nil_provider.define_singleton_method(:context_priority) { 50 }
        nil_provider.define_singleton_method(:context_contribution) { |budget:| nil }
        nil_provider.define_singleton_method(:context_active?) { true }
        nil_provider.define_singleton_method(:context_optional?) { true }
        nil_provider.define_singleton_method(:context_relevance) { |task:, step:| 1.0 }

        orchestrator = described_class.new(providers: [nil_provider])
        result = orchestrator.assemble(task: "test", step: 1)
        expect(result.content).to eq("")
      end
    end

    context "with error in provider" do
      it "handles errors gracefully" do
        error_provider = Object.new
        error_provider.define_singleton_method(:context_key) { :error }
        error_provider.define_singleton_method(:context_layer) { Smolagents::Context::Layer::STRATEGIC }
        error_provider.define_singleton_method(:context_priority) { 50 }
        error_provider.define_singleton_method(:context_contribution) { |budget:| raise "Oops!" }
        error_provider.define_singleton_method(:context_active?) { true }
        error_provider.define_singleton_method(:context_optional?) { true }
        error_provider.define_singleton_method(:context_relevance) { |task:, step:| 1.0 }

        orchestrator = described_class.new(providers: [error_provider])
        result = orchestrator.assemble(task: "test", step: 1)
        expect(result.content).to include("[Error from error: Oops!]")
      end
    end
  end

  describe Smolagents::Context::AssemblyResult do
    let(:result) do
      described_class.new(
        content: "Full content",
        layers: { strategic: "Strategic", tactical: "Tactical" },
        metadata: { provider_count: 2 }
      )
    end

    it "provides content via to_s" do
      expect(result.to_s).to eq("Full content")
    end

    it "provides layer content" do
      expect(result.layer_content(Smolagents::Context::Layer::STRATEGIC)).to eq("Strategic")
    end

    it "provides metadata" do
      expect(result.metadata[:provider_count]).to eq(2)
    end
  end

  describe "metadata" do
    it "includes provider count" do
      p1 = create_provider(key: :one, content: "One")
      p2 = create_provider(key: :two, content: "Two")
      orchestrator = described_class.new(providers: [p1, p2])
      result = orchestrator.assemble(task: "test", step: 1)
      expect(result.metadata[:provider_count]).to eq(2)
    end

    it "includes layers used" do
      provider = create_provider(key: :test, layer: Smolagents::Context::Layer::TACTICAL, content: "Test")
      orchestrator = described_class.new(providers: [provider])
      result = orchestrator.assemble(task: "test", step: 1)
      expect(result.metadata[:layers_used]).to include(:tactical)
    end

    it "includes providers included" do
      provider = create_provider(key: :included, content: "Test")
      orchestrator = described_class.new(providers: [provider])
      result = orchestrator.assemble(task: "test", step: 1)
      expect(result.metadata[:providers_included]).to include(:included)
    end

    it "includes budget allocations" do
      provider = create_provider(key: :budgeted, content: "Test")
      orchestrator = described_class.new(providers: [provider], total_budget: 1000)
      result = orchestrator.assemble(task: "test", step: 1)
      expect(result.metadata[:budgets]).to have_key(:budgeted)
    end
  end

  describe "integration" do
    it "builds complete context from multiple providers" do
      goal = create_provider(
        key: :goal,
        layer: Smolagents::Context::Layer::PERSISTENT,
        priority: 100,
        content: "# == Goal ==\n# Find Ruby 4.0 features"
      )
      plan = create_provider(
        key: :plan,
        layer: Smolagents::Context::Layer::STRATEGIC,
        priority: 80,
        content: "# == Plan ==\n# 1. Search\n# 2. Summarize"
      )
      step = create_provider(
        key: :step,
        layer: Smolagents::Context::Layer::TACTICAL,
        priority: 90,
        content: "# == Step ==\n# Step 3 of 10"
      )

      orchestrator = described_class.new(providers: [goal, plan, step])
      result = orchestrator.assemble(task: "Find Ruby info", step: 3)

      expect(result.content).to include("Goal")
      expect(result.content).to include("Plan")
      expect(result.content).to include("Step")
      expect(result.metadata[:provider_count]).to eq(3)
    end
  end
end
