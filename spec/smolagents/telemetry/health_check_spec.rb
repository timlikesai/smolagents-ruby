require "spec_helper"

RSpec.describe Smolagents::Telemetry::SmolagentsHealthCheck do
  describe ".check" do
    it "returns a hash with healthy and checks keys" do
      result = described_class.check

      expect(result).to have_key(:healthy)
      expect(result).to have_key(:checks)
    end

    it "includes all check categories" do
      result = described_class.check

      expect(result[:checks]).to have_key(:configuration)
      expect(result[:checks]).to have_key(:tools)
      expect(result[:checks]).to have_key(:memory)
    end

    it "marks system as healthy when all checks pass" do
      result = described_class.check

      expect(result[:healthy]).to be(true)
    end

    it "marks system as unhealthy when memory check fails" do
      allow(GC).to receive(:stat).and_return({ heap_live_slots: 5000, count: 10 })

      result = described_class.check

      expect(result[:healthy]).to be(false)
    end
  end

  describe ".check_configuration" do
    it "returns frozen status" do
      result = described_class.check_configuration

      expect(result).to have_key(:frozen)
      expect(result[:frozen]).to be(true).or be(false)
    end

    it "returns max_steps from configuration" do
      result = described_class.check_configuration

      expect(result).to have_key(:max_steps)
      expect(result[:max_steps]).to be_a(Integer)
    end

    it "returns log_level from configuration" do
      result = described_class.check_configuration

      expect(result).to have_key(:log_level)
      expect(result[:log_level]).to be_a(Symbol)
    end

    it "reflects current configuration values" do
      Smolagents.configure { |c| c.max_steps = 42 }

      result = described_class.check_configuration

      expect(result[:max_steps]).to eq(42)
    end
  end

  describe ".check_tools" do
    it "returns toolkit count" do
      result = described_class.check_tools

      expect(result).to have_key(:toolkit_count)
      expect(result[:toolkit_count]).to be > 0
    end

    it "returns available toolkits" do
      result = described_class.check_tools

      expect(result).to have_key(:available_toolkits)
      expect(result[:available_toolkits]).to be_an(Array)
    end

    it "includes expected toolkits" do
      result = described_class.check_tools

      expect(result[:available_toolkits]).to include(:search, :web, :data, :research)
    end

    it "counts toolkits correctly" do
      result = described_class.check_tools
      expected_count = Smolagents::Toolkits.names.size

      expect(result[:toolkit_count]).to eq(expected_count)
    end
  end

  describe ".check_memory" do
    it "returns heap_slots from GC stats" do
      result = described_class.check_memory

      expect(result).to have_key(:heap_slots)
      expect(result[:heap_slots]).to be_a(Integer)
    end

    it "returns gc_count from GC stats" do
      result = described_class.check_memory

      expect(result).to have_key(:gc_count)
      expect(result[:gc_count]).to be_a(Integer)
    end

    it "returns healthy status" do
      result = described_class.check_memory

      expect(result).to have_key(:healthy)
      expect(result[:healthy]).to be(true).or be(false)
    end

    it "marks as healthy when heap_slots exceeds threshold" do
      allow(GC).to receive(:stat).and_return({ heap_live_slots: 20_000, count: 5 })

      result = described_class.check_memory

      expect(result[:healthy]).to be(true)
    end

    it "marks as unhealthy when heap_slots below threshold" do
      allow(GC).to receive(:stat).and_return({ heap_live_slots: 5000, count: 5 })

      result = described_class.check_memory

      expect(result[:healthy]).to be(false)
    end

    it "handles missing heap_live_slots by falling back to heap_available_slots" do
      allow(GC).to receive(:stat).and_return({ heap_available_slots: 15_000, count: 5 })

      result = described_class.check_memory

      expect(result[:heap_slots]).to eq(15_000)
      expect(result[:healthy]).to be(true)
    end

    it "handles missing slot data by defaulting to 0" do
      allow(GC).to receive(:stat).and_return({ count: 5 })

      result = described_class.check_memory

      expect(result[:heap_slots]).to eq(0)
      expect(result[:healthy]).to be(false)
    end
  end
end
