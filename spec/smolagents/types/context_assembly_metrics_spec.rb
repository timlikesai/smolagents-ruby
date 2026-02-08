require "spec_helper"
require "smolagents/types/context_assembly_metrics"

RSpec.describe Smolagents::Types::ContextAssemblyMetrics do
  describe ".empty" do
    it "creates metrics with empty collections" do
      metrics = described_class.empty
      expect(metrics.provider_budgets).to eq({})
      expect(metrics.provider_contributions).to eq({})
      expect(metrics.providers_included).to eq([])
      expect(metrics.providers_excluded).to eq([])
    end

    it "accepts budget parameter" do
      metrics = described_class.empty(budget: 4000)
      expect(metrics.total_budget).to eq(4000)
    end

    it "defaults to zero total_used" do
      metrics = described_class.empty(budget: 1000)
      expect(metrics.total_used).to eq(0)
    end
  end

  describe "#utilization_percent" do
    it "calculates percentage correctly" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 1000,
        total_used: 755,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.utilization_percent).to eq(75.5)
    end

    it "rounds to one decimal" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 1000,
        total_used: 333,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.utilization_percent).to eq(33.3)
    end

    it "returns 0.0 for zero budget" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 0,
        total_used: 100,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.utilization_percent).to eq(0.0)
    end

    it "can exceed 100% when over budget" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 100,
        total_used: 150,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.utilization_percent).to eq(150.0)
    end
  end

  describe "#headroom" do
    it "returns remaining budget" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 1000,
        total_used: 750,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.headroom).to eq(250)
    end

    it "can be negative when over budget" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 100,
        total_used: 150,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.headroom).to eq(-50)
    end

    it "returns zero at exact budget" do
      metrics = described_class.new(
        provider_budgets: {},
        provider_contributions: {},
        total_budget: 500,
        total_used: 500,
        providers_included: [],
        providers_excluded: []
      )
      expect(metrics.headroom).to eq(0)
    end
  end

  describe "full metrics" do
    it "tracks provider-level information" do
      metrics = described_class.new(
        provider_budgets: { goal: 500, plan: 300, history: 200 },
        provider_contributions: { goal: 400, plan: 250 },
        total_budget: 1000,
        total_used: 650,
        providers_included: %i[goal plan],
        providers_excluded: [:history]
      )

      expect(metrics.provider_budgets[:goal]).to eq(500)
      expect(metrics.provider_contributions[:goal]).to eq(400)
      expect(metrics.providers_included).to contain_exactly(:goal, :plan)
      expect(metrics.providers_excluded).to eq([:history])
    end
  end
end
