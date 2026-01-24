require "spec_helper"
require "smolagents/context/providers/base"

RSpec.describe Smolagents::Context::Providers do
  describe Smolagents::Context::Providers::AdapterProvider do
    let(:content_proc) { -> { "test content" } }
    let(:provider) do
      described_class.build(
        key: :test,
        layer: Smolagents::Context::Layer::TACTICAL,
        content_proc:
      )
    end

    it "implements Provider protocol" do
      expect(provider.context_key).to eq(:test)
      expect(provider.context_layer).to eq(Smolagents::Context::Layer::TACTICAL)
      expect(provider.context_contribution(budget: 100)).to eq("test content")
    end

    it "has default priority of 50" do
      expect(provider.context_priority).to eq(50)
    end

    it "is optional by default" do
      expect(provider.context_optional?).to be true
    end

    it "accepts custom priority" do
      custom = described_class.build(
        key: :custom, layer: Smolagents::Context::Layer::STRATEGIC,
        content_proc: -> { "x" }, priority: 90
      )
      expect(custom.context_priority).to eq(90)
    end

    it "accepts optional flag" do
      required = described_class.build(
        key: :required, layer: Smolagents::Context::Layer::PERSISTENT,
        content_proc: -> { "x" }, optional: false
      )
      expect(required.context_optional?).to be false
    end

    it "calls content_proc for contribution" do
      call_count = 0
      counting_proc = lambda do
        call_count += 1
        "counted"
      end
      p = described_class.build(key: :count, layer: Smolagents::Context::Layer::TACTICAL, content_proc: counting_proc)

      p.context_contribution(budget: 100)
      p.context_contribution(budget: 100)

      expect(call_count).to eq(2)
    end

    it "can return nil from content_proc" do
      nil_proc = -> {}
      p = described_class.build(key: :nil, layer: Smolagents::Context::Layer::TACTICAL, content_proc: nil_proc)
      expect(p.context_contribution(budget: 100)).to be_nil
    end
  end

  describe ".step_context" do
    let(:mock_runtime) do
      runtime = Object.new
      runtime.define_singleton_method(:build_step_context) { "[CONTEXT]\nStep: 1 of 10" }
      runtime
    end

    it "creates a TACTICAL layer provider" do
      provider = described_class.step_context(mock_runtime)
      expect(provider.context_layer).to eq(Smolagents::Context::Layer::TACTICAL)
    end

    it "has key :step_context" do
      provider = described_class.step_context(mock_runtime)
      expect(provider.context_key).to eq(:step_context)
    end

    it "has priority 90" do
      provider = described_class.step_context(mock_runtime)
      expect(provider.context_priority).to eq(90)
    end

    it "delegates to runtime.build_step_context" do
      provider = described_class.step_context(mock_runtime)
      expect(provider.context_contribution(budget: 100)).to eq("[CONTEXT]\nStep: 1 of 10")
    end

    it "returns nil when runtime returns nil" do
      runtime = Object.new
      runtime.define_singleton_method(:build_step_context) { nil }
      provider = described_class.step_context(runtime)
      expect(provider.context_contribution(budget: 100)).to be_nil
    end
  end

  describe ".planning" do
    let(:plan_context) do
      ctx = Object.new
      ctx.define_singleton_method(:initialized?) { true }
      ctx.define_singleton_method(:plan) { "1. Search\n2. Summarize" }
      ctx
    end

    let(:mock_runtime) do
      runtime = Object.new
      runtime.instance_variable_set(:@planning_interval, 3)
      runtime.instance_variable_set(:@plan_context, plan_context)
      runtime
    end

    it "creates a STRATEGIC layer provider" do
      provider = described_class.planning(mock_runtime)
      expect(provider.context_layer).to eq(Smolagents::Context::Layer::STRATEGIC)
    end

    it "has key :planning" do
      provider = described_class.planning(mock_runtime)
      expect(provider.context_key).to eq(:planning)
    end

    it "has priority 80" do
      provider = described_class.planning(mock_runtime)
      expect(provider.context_priority).to eq(80)
    end

    it "returns plan content when plan exists" do
      provider = described_class.planning(mock_runtime)
      content = provider.context_contribution(budget: 100)
      expect(content).to include("CURRENT PLAN:")
      expect(content).to include("1. Search")
      expect(content).to include("Execute the next step")
    end

    it "returns nil when planning_interval is nil" do
      runtime = Object.new
      runtime.instance_variable_set(:@planning_interval, nil)
      provider = described_class.planning(runtime)
      expect(provider.context_contribution(budget: 100)).to be_nil
    end

    it "returns nil when planning_interval is zero" do
      runtime = Object.new
      runtime.instance_variable_set(:@planning_interval, 0)
      provider = described_class.planning(runtime)
      expect(provider.context_contribution(budget: 100)).to be_nil
    end

    it "returns nil when plan_context not initialized" do
      ctx = Object.new
      ctx.define_singleton_method(:initialized?) { false }
      runtime = Object.new
      runtime.instance_variable_set(:@planning_interval, 3)
      runtime.instance_variable_set(:@plan_context, ctx)
      provider = described_class.planning(runtime)
      expect(provider.context_contribution(budget: 100)).to be_nil
    end

    it "returns nil when plan is empty" do
      ctx = Object.new
      ctx.define_singleton_method(:initialized?) { true }
      ctx.define_singleton_method(:plan) { "" }
      runtime = Object.new
      runtime.instance_variable_set(:@planning_interval, 3)
      runtime.instance_variable_set(:@plan_context, ctx)
      provider = described_class.planning(runtime)
      expect(provider.context_contribution(budget: 100)).to be_nil
    end
  end
end
