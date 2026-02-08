require "spec_helper"

RSpec.describe Smolagents::Types::ToolRouterConfig do
  describe "type behavior" do
    let(:instance) { described_class.default }

    it_behaves_like "a frozen type"
  end

  describe ".default" do
    subject(:config) { described_class.default }

    it "is disabled by default" do
      expect(config.enabled?).to be false
      expect(config.disabled?).to be true
      expect(config.has_dispatcher?).to be false
    end

    it "has sensible thresholds" do
      expect(config.high_confidence_threshold).to eq(0.8)
      expect(config.low_confidence_threshold).to eq(0.5)
      expect(config.max_parallel_calls).to eq(3)
    end

    it "enables fallback by default" do
      expect(config.fallback_on_error?).to be true
    end

    it "disables trace collection by default" do
      expect(config.collect_traces?).to be false
    end
  end

  describe ".with_model" do
    subject(:config) { described_class.with_model("test-model") }

    it "enables routing" do
      expect(config.enabled?).to be true
      expect(config.has_dispatcher?).to be true
    end

    it "sets model_id" do
      expect(config.model_id).to eq("test-model")
    end

    it "accepts collect_traces option" do
      config = described_class.with_model("test", collect_traces: true)
      expect(config.collect_traces?).to be true
    end
  end

  describe ".function_gemma" do
    subject(:config) { described_class.function_gemma }

    it "sets FunctionGemma model ID" do
      expect(config.model_id).to eq("functiongemma-270m-it-mlx")
      expect(config.enabled?).to be true
    end
  end

  describe ".aggressive" do
    subject(:config) { described_class.aggressive("fast-model") }

    it "lowers thresholds" do
      expect(config.high_confidence_threshold).to eq(0.6)
      expect(config.low_confidence_threshold).to eq(0.3)
      expect(config.max_parallel_calls).to eq(5)
    end
  end

  describe ".conservative" do
    subject(:config) { described_class.conservative("careful-model") }

    it "raises thresholds" do
      expect(config.high_confidence_threshold).to eq(0.9)
      expect(config.low_confidence_threshold).to eq(0.7)
      expect(config.max_parallel_calls).to eq(2)
    end

    it "enables trace collection" do
      expect(config.collect_traces?).to be true
    end
  end

  describe "#with_thresholds" do
    it "returns new config with updated thresholds" do
      original = described_class.default
      updated = original.with_thresholds(high: 0.9, low: 0.6)

      expect(updated.high_confidence_threshold).to eq(0.9)
      expect(updated.low_confidence_threshold).to eq(0.6)
      expect(original.high_confidence_threshold).to eq(0.8) # Unchanged
    end
  end

  describe "#with_trace_collection" do
    it "returns new config with tracing enabled" do
      original = described_class.default
      updated = original.with_trace_collection

      expect(updated.collect_traces?).to be true
      expect(original.collect_traces?).to be false
    end
  end
end
