require "spec_helper"

RSpec.describe Smolagents::Concerns::AgentHealth::Health do
  subject(:health_check) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::AgentHealth::Health

      attr_accessor :model, :memory, :tools

      def initialize
        @model = nil
        @memory = nil
        @tools = {}
      end
    end
  end

  let(:mock_model) do
    double("Model", healthy?: true)
  end

  let(:mock_memory) do
    double("Memory")
  end

  let(:mock_tool) do
    double("Tool", initialized?: true)
  end

  describe "#live?" do
    it "returns false when model is missing" do
      health_check.memory = mock_memory
      expect(health_check.live?).to be false
    end

    it "returns false when memory is missing" do
      health_check.model = mock_model
      expect(health_check.live?).to be false
    end

    it "returns true when model and memory are present" do
      health_check.model = mock_model
      health_check.memory = mock_memory
      expect(health_check.live?).to be true
    end
  end

  describe "#ready?" do
    before do
      health_check.model = mock_model
      health_check.memory = mock_memory
    end

    it "returns false when not live" do
      health_check.model = nil
      expect(health_check.ready?).to be false
    end

    it "returns false when model is unhealthy" do
      allow(mock_model).to receive(:healthy?).with(cache_for: 30).and_return(false)
      expect(health_check.ready?).to be false
    end

    it "returns true when model is healthy and no tools" do
      allow(mock_model).to receive(:healthy?).with(cache_for: 30).and_return(true)
      expect(health_check.ready?).to be true
    end

    it "returns true when all tools are initialized" do
      allow(mock_model).to receive(:healthy?).with(cache_for: 30).and_return(true)
      health_check.tools = { search: mock_tool }
      expect(health_check.ready?).to be true
    end

    it "returns false when any tool is not initialized" do
      allow(mock_model).to receive(:healthy?).with(cache_for: 30).and_return(true)
      uninitialized_tool = double("Tool", initialized?: false)
      health_check.tools = { search: mock_tool, broken: uninitialized_tool }
      expect(health_check.ready?).to be false
    end

    context "when model does not support health checks" do
      let(:mock_model) { Object.new }

      it "assumes model is ready" do
        health_check.model = mock_model
        health_check.memory = mock_memory
        expect(health_check.ready?).to be true
      end
    end
  end

  describe "#liveness_probe" do
    it "returns ok status when live" do
      health_check.model = mock_model
      health_check.memory = mock_memory
      probe = health_check.liveness_probe

      expect(probe[:status]).to eq("ok")
      expect(probe[:checks][:model_present]).to be true
      expect(probe[:checks][:memory_present]).to be true
      expect(probe[:timestamp]).to be_a(String)
    end

    it "returns fail status when not live" do
      probe = health_check.liveness_probe

      expect(probe[:status]).to eq("fail")
      expect(probe[:checks][:model_present]).to be false
      expect(probe[:checks][:memory_present]).to be false
    end
  end

  describe "#readiness_probe" do
    before do
      health_check.model = mock_model
      health_check.memory = mock_memory
      allow(mock_model).to receive(:healthy?).with(cache_for: 30).and_return(true)
    end

    it "returns ok status when ready" do
      probe = health_check.readiness_probe

      expect(probe[:status]).to eq("ok")
      expect(probe[:checks][:live]).to be true
      expect(probe[:checks][:model_healthy]).to be true
      expect(probe[:checks][:tools_initialized]).to be true
      expect(probe[:timestamp]).to be_a(String)
    end

    it "returns fail status when not ready" do
      allow(mock_model).to receive(:healthy?).with(cache_for: 30).and_return(false)
      probe = health_check.readiness_probe

      expect(probe[:status]).to eq("fail")
      expect(probe[:checks][:model_healthy]).to be false
    end
  end
end
