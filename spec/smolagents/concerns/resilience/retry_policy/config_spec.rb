require "smolagents"

RSpec.describe Smolagents::Concerns::RetryPolicyConfig do
  describe "DEFAULTS" do
    it "has sensible default values" do
      expect(described_class::DEFAULTS[:max_attempts]).to eq(3)
      expect(described_class::DEFAULTS[:base_interval]).to eq(1.0)
      expect(described_class::DEFAULTS[:max_interval]).to eq(30.0)
      expect(described_class::DEFAULTS[:backoff]).to eq(:exponential)
      expect(described_class::DEFAULTS[:jitter]).to eq(0.5)
    end

    it "is frozen" do
      expect(described_class::DEFAULTS).to be_frozen
    end
  end

  describe "AGGRESSIVE" do
    it "has more attempts and shorter intervals" do
      expect(described_class::AGGRESSIVE[:max_attempts]).to eq(5)
      expect(described_class::AGGRESSIVE[:base_interval]).to eq(0.5)
      expect(described_class::AGGRESSIVE[:max_interval]).to eq(15.0)
      expect(described_class::AGGRESSIVE[:jitter]).to eq(0.3)
    end

    it "is frozen" do
      expect(described_class::AGGRESSIVE).to be_frozen
    end
  end

  describe "CONSERVATIVE" do
    it "has fewer attempts and longer intervals" do
      expect(described_class::CONSERVATIVE[:max_attempts]).to eq(2)
      expect(described_class::CONSERVATIVE[:base_interval]).to eq(2.0)
      expect(described_class::CONSERVATIVE[:max_interval]).to eq(60.0)
      expect(described_class::CONSERVATIVE[:jitter]).to eq(1.0)
    end

    it "is frozen" do
      expect(described_class::CONSERVATIVE).to be_frozen
    end
  end

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to be_a(Hash)
      expect(methods.keys).to include(:DEFAULTS, :AGGRESSIVE, :CONSERVATIVE)
    end
  end
end
