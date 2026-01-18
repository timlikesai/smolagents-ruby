require "smolagents"

RSpec.describe Smolagents::Types::Isolation::ResourceLimits do
  let(:instance) { described_class.default }

  it_behaves_like "a data type"

  describe ".default" do
    subject(:limits) { described_class.default }

    it "returns a ResourceLimits instance" do
      expect(limits).to be_a(described_class)
    end

    it "uses default timeout" do
      expect(limits.timeout_seconds).to eq(Smolagents::Types::Isolation::DEFAULT_TIMEOUT_SECONDS)
    end

    it "uses default memory limit" do
      expect(limits.max_memory_bytes).to eq(Smolagents::Types::Isolation::DEFAULT_MAX_MEMORY_BYTES)
    end

    it "uses default output limit" do
      expect(limits.max_output_bytes).to eq(Smolagents::Types::Isolation::DEFAULT_MAX_OUTPUT_BYTES)
    end

    it "has sensible defaults" do
      expect(limits.timeout_seconds).to eq(5.0)
      expect(limits.max_memory_bytes).to eq(50 * 1024 * 1024) # 50MB
      expect(limits.max_output_bytes).to eq(50 * 1024)        # 50KB
    end
  end

  describe ".with_timeout" do
    subject(:limits) { described_class.with_timeout(30.0) }

    it "sets custom timeout" do
      expect(limits.timeout_seconds).to eq(30.0)
    end

    it "uses default memory limit" do
      expect(limits.max_memory_bytes).to eq(Smolagents::Types::Isolation::DEFAULT_MAX_MEMORY_BYTES)
    end

    it "uses default output limit" do
      expect(limits.max_output_bytes).to eq(Smolagents::Types::Isolation::DEFAULT_MAX_OUTPUT_BYTES)
    end

    it "handles small timeouts" do
      limits = described_class.with_timeout(0.1)
      expect(limits.timeout_seconds).to eq(0.1)
    end

    it "handles large timeouts" do
      limits = described_class.with_timeout(3600.0)
      expect(limits.timeout_seconds).to eq(3600.0)
    end
  end

  describe ".permissive" do
    subject(:limits) { described_class.permissive }

    it "sets high timeout" do
      expect(limits.timeout_seconds).to eq(60.0)
    end

    it "sets high memory limit (500MB)" do
      expect(limits.max_memory_bytes).to eq(500 * 1024 * 1024)
    end

    it "sets high output limit (1MB)" do
      expect(limits.max_output_bytes).to eq(1024 * 1024)
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      hash = instance.to_h
      expect(hash.keys).to contain_exactly(:timeout_seconds, :max_memory_bytes, :max_output_bytes)
    end

    it "includes correct values" do
      hash = instance.to_h
      expect(hash[:timeout_seconds]).to eq(instance.timeout_seconds)
      expect(hash[:max_memory_bytes]).to eq(instance.max_memory_bytes)
      expect(hash[:max_output_bytes]).to eq(instance.max_output_bytes)
    end
  end

  describe "pattern matching" do
    it "matches on timeout_seconds" do
      result = case instance
               in timeout_seconds: 5.0
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end

    it "matches on max_memory_bytes" do
      expected = 50 * 1024 * 1024
      result = case instance
               in max_memory_bytes: ^expected
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end

    it "matches on multiple fields" do
      custom = described_class.new(timeout_seconds: 10.0, max_memory_bytes: 100, max_output_bytes: 200)

      result = case custom
               in timeout_seconds: 10.0, max_output_bytes: 200
                 "matched"
               else
                 "not matched"
               end

      expect(result).to eq("matched")
    end
  end

  describe "edge cases" do
    it "accepts zero timeout" do
      limits = described_class.new(timeout_seconds: 0, max_memory_bytes: 0, max_output_bytes: 0)
      expect(limits.timeout_seconds).to eq(0)
    end

    it "accepts very large values" do
      limits = described_class.new(
        timeout_seconds: Float::INFINITY,
        max_memory_bytes: 2**62,
        max_output_bytes: 2**62
      )
      expect(limits.timeout_seconds).to eq(Float::INFINITY)
    end

    it "creates equal instances with same values" do
      limits1 = described_class.default
      limits2 = described_class.default
      expect(limits1).to eq(limits2)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(instance).to be_frozen
    end

    it "#with returns new instance" do
      updated = instance.with(timeout_seconds: 100.0)
      expect(updated).to be_frozen
      expect(updated.timeout_seconds).to eq(100.0)
      expect(instance.timeout_seconds).to eq(5.0)
    end
  end
end
