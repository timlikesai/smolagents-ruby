require "spec_helper"
require "smolagents/context/budget_allocator"
require "smolagents/context/provider"

RSpec.describe Smolagents::Context::BudgetAllocator do
  let(:allocator) { described_class.new(total_budget: 1000) }

  # Helper to create provider instances
  def create_provider(key:, priority: 50, relevance: 1.0, optional: true, active: true, layer: nil)
    provider = Object.new
    provider.define_singleton_method(:context_key) { key }
    provider.define_singleton_method(:context_priority) { priority }
    provider.define_singleton_method(:context_relevance) { |task:, step:| relevance }
    provider.define_singleton_method(:context_optional?) { optional }
    provider.define_singleton_method(:context_active?) { active }
    provider.define_singleton_method(:context_layer) { layer || Smolagents::Context::Layer::STRATEGIC }
    provider
  end

  describe "#initialize" do
    it "accepts total_budget parameter" do
      alloc = described_class.new(total_budget: 2000)
      expect(alloc.total_budget).to eq(2000)
    end

    it "has default budget" do
      alloc = described_class.new
      expect(alloc.total_budget).to eq(described_class::DEFAULT_BUDGET)
    end
  end

  describe "#score" do
    it "calculates priority × relevance" do
      provider = create_provider(key: :test, priority: 80, relevance: 0.5)
      expect(allocator.score(provider, task: "test", step: 1)).to eq(40.0)
    end

    it "clamps relevance to 0.0-1.0" do
      provider = create_provider(key: :test, priority: 100, relevance: 1.5)
      expect(allocator.score(provider, task: "test", step: 1)).to eq(100.0)
    end

    it "handles zero relevance" do
      provider = create_provider(key: :test, priority: 100, relevance: 0.0)
      expect(allocator.score(provider, task: "test", step: 1)).to eq(0.0)
    end

    it "handles zero priority" do
      provider = create_provider(key: :test, priority: 0, relevance: 1.0)
      expect(allocator.score(provider, task: "test", step: 1)).to eq(0.0)
    end
  end

  describe "#allocate" do
    context "with empty providers" do
      it "returns empty hash" do
        expect(allocator.allocate([], task: "test", step: 1)).to eq({})
      end
    end

    context "with single provider" do
      it "allocates full budget" do
        provider = create_provider(key: :solo, priority: 50)
        result = allocator.allocate([provider], task: "test", step: 1)
        expect(result[:solo]).to eq(1000)
      end
    end

    context "with multiple equal providers" do
      it "distributes proportionally by score" do
        p1 = create_provider(key: :one, priority: 50)
        p2 = create_provider(key: :two, priority: 50)
        result = allocator.allocate([p1, p2], task: "test", step: 1)
        expect(result[:one]).to be_within(50).of(500)
        expect(result[:two]).to be_within(50).of(500)
      end
    end

    context "with different priorities" do
      it "gives more budget to higher priority" do
        high = create_provider(key: :high, priority: 100)
        low = create_provider(key: :low, priority: 50)
        result = allocator.allocate([high, low], task: "test", step: 1)
        expect(result[:high]).to be > result[:low]
      end
    end

    context "with different relevance" do
      it "gives more budget to higher relevance" do
        relevant = create_provider(key: :relevant, priority: 50, relevance: 1.0)
        irrelevant = create_provider(key: :irrelevant, priority: 50, relevance: 0.5)
        result = allocator.allocate([relevant, irrelevant], task: "test", step: 1)
        expect(result[:relevant]).to be > result[:irrelevant]
      end
    end

    context "with inactive providers" do
      it "excludes inactive providers" do
        active = create_provider(key: :active, active: true)
        inactive = create_provider(key: :inactive, active: false)
        result = allocator.allocate([active, inactive], task: "test", step: 1)
        expect(result.keys).to eq([:active])
      end
    end

    context "with required providers" do
      it "guarantees minimum budget for required providers" do
        required = create_provider(key: :required, optional: false, priority: 10, relevance: 0.1)
        optional = create_provider(key: :optional, optional: true, priority: 100)
        result = allocator.allocate([required, optional], task: "test", step: 1)
        expect(result[:required]).to be >= described_class::MIN_PROVIDER_BUDGET
      end

      it "allocates to required even with zero score" do
        required = create_provider(key: :required, optional: false, priority: 0)
        result = allocator.allocate([required], task: "test", step: 1)
        expect(result[:required]).to be >= described_class::MIN_PROVIDER_BUDGET
      end
    end

    context "with all zero scores" do
      it "distributes equally" do
        p1 = create_provider(key: :one, priority: 0)
        p2 = create_provider(key: :two, priority: 0)
        result = allocator.allocate([p1, p2], task: "test", step: 1)
        expect(result[:one]).to eq(500)
        expect(result[:two]).to eq(500)
      end
    end

    context "with small budget" do
      let(:small_allocator) { described_class.new(total_budget: 100) }

      it "respects minimum provider budget" do
        providers = (1..5).map { |i| create_provider(key: :"p#{i}", priority: 50) }
        result = small_allocator.allocate(providers, task: "test", step: 1)
        result.each_value do |budget|
          expect(budget).to be >= described_class::MIN_PROVIDER_BUDGET
        end
      end

      it "may exclude low-scoring optional providers" do
        high = create_provider(key: :high, priority: 100)
        low = create_provider(key: :low, priority: 10, relevance: 0.1)
        result = small_allocator.allocate([high, low], task: "test", step: 1)
        # Low scorer might not get allocation if below minimum
        expect(result[:high]).to be_positive
      end
    end

    context "integration with real providers" do
      let(:provider_class) do
        Class.new do
          include Smolagents::Context::Provider

          def initialize(key, priority: 50, relevance: 1.0, optional: true)
            @key = key
            @priority = priority
            @relevance = relevance
            @optional = optional
          end

          def context_key = @key
          def context_layer = Smolagents::Context::Layer::STRATEGIC
          def context_contribution(budget:) = "content"
          def context_priority = @priority
          def context_relevance(task:, step:) = @relevance
          def context_optional? = @optional
        end
      end

      it "works with Provider instances" do
        p1 = provider_class.new(:goals, priority: 80)
        p2 = provider_class.new(:plan, priority: 70)
        result = allocator.allocate([p1, p2], task: "test", step: 1)
        expect(result.keys).to contain_exactly(:goals, :plan)
        expect(result.values.sum).to be <= 1000
      end
    end
  end

  describe "budget constraints" do
    it "never exceeds total budget", max_time: 0.1 do
      providers = (1..10).map { |i| create_provider(key: :"p#{i}", priority: rand(10..100)) }
      result = allocator.allocate(providers, task: "test", step: 1)
      expect(result.values.sum).to be <= allocator.total_budget
    end

    it "uses most of budget with active providers" do
      providers = (1..3).map { |i| create_provider(key: :"p#{i}", priority: 50) }
      result = allocator.allocate(providers, task: "test", step: 1)
      expect(result.values.sum).to be >= allocator.total_budget * 0.5
    end
  end
end
