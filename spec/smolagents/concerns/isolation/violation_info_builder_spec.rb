require "spec_helper"

RSpec.describe Smolagents::Concerns::Isolation::ViolationInfoBuilder do
  let(:limits) do
    Smolagents::Types::Isolation::ResourceLimits.new(
      timeout_seconds: 5.0,
      max_memory_bytes: 50_000_000,
      max_output_bytes: 10_000
    )
  end

  describe ".build" do
    context "when timeout is exceeded" do
      let(:metrics) do
        Smolagents::Types::Isolation::ResourceMetrics.new(
          duration_ms: 10_000.0, # 10 seconds - exceeds 5 second limit
          memory_bytes: 10_000_000,
          output_bytes: 1000
        )
      end

      it "identifies timeout violation" do
        info = described_class.build("search_tool", metrics, limits)

        expect(info[:resource_type]).to eq(:timeout)
        expect(info[:tool_name]).to eq("search_tool")
        expect(info[:message]).to include("timeout")
      end

      it "includes limit and actual values" do
        info = described_class.build("search_tool", metrics, limits)

        expect(info[:limit_value]).to eq(5000) # 5 seconds * 1000 ms
        expect(info[:actual_value]).to eq(10_000.0)
      end
    end

    context "when memory is exceeded" do
      let(:metrics) do
        Smolagents::Types::Isolation::ResourceMetrics.new(
          duration_ms: 1000.0, # Within limit
          memory_bytes: 60_000_000, # Exceeds 50MB limit
          output_bytes: 1000
        )
      end

      it "identifies memory violation" do
        info = described_class.build("heavy_tool", metrics, limits)

        expect(info[:resource_type]).to eq(:memory)
        expect(info[:message]).to include("memory")
      end

      it "includes limit and actual values" do
        info = described_class.build("heavy_tool", metrics, limits)

        expect(info[:limit_value]).to eq(50_000_000)
        expect(info[:actual_value]).to eq(60_000_000)
      end
    end

    context "when output is exceeded" do
      let(:metrics) do
        Smolagents::Types::Isolation::ResourceMetrics.new(
          duration_ms: 1000.0, # Within limit
          memory_bytes: 10_000_000, # Within limit
          output_bytes: 20_000 # Exceeds 10KB limit
        )
      end

      it "identifies output violation" do
        info = described_class.build("verbose_tool", metrics, limits)

        expect(info[:resource_type]).to eq(:output)
        expect(info[:message]).to include("output")
      end

      it "includes limit and actual values" do
        info = described_class.build("verbose_tool", metrics, limits)

        expect(info[:limit_value]).to eq(10_000)
        expect(info[:actual_value]).to eq(20_000)
      end
    end
  end

  describe ".detect_type" do
    it "prioritizes timeout violations" do
      metrics = Smolagents::Types::Isolation::ResourceMetrics.new(
        duration_ms: 10_000.0,
        memory_bytes: 60_000_000,
        output_bytes: 20_000
      )

      type = described_class.detect_type(metrics, limits)

      expect(type).to eq(:timeout)
    end

    it "checks memory after timeout" do
      metrics = Smolagents::Types::Isolation::ResourceMetrics.new(
        duration_ms: 1000.0,
        memory_bytes: 60_000_000,
        output_bytes: 20_000
      )

      type = described_class.detect_type(metrics, limits)

      expect(type).to eq(:memory)
    end

    it "falls back to output" do
      metrics = Smolagents::Types::Isolation::ResourceMetrics.new(
        duration_ms: 1000.0,
        memory_bytes: 10_000_000,
        output_bytes: 20_000
      )

      type = described_class.detect_type(metrics, limits)

      expect(type).to eq(:output)
    end
  end
end
