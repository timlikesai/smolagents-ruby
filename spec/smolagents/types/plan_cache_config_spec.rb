require "spec_helper"

RSpec.describe Smolagents::Types::PlanCacheConfig do
  describe ".default" do
    it "creates config with caching enabled" do
      config = described_class.default

      expect(config.enabled).to be true
      expect(config.max_size).to eq(100)
      expect(config.ttl_seconds).to eq(3600)
      expect(config.similarity_threshold).to eq(0.85)
    end
  end

  describe ".disabled" do
    it "creates config with caching disabled" do
      config = described_class.disabled

      expect(config.enabled).to be false
      expect(config.max_size).to eq(0)
      expect(config.ttl_seconds).to eq(0)
      expect(config.similarity_threshold).to eq(1.0)
    end
  end

  describe "#disabled?" do
    it "returns false for default config" do
      config = described_class.default

      expect(config.disabled?).to be false
    end

    it "returns true for disabled config" do
      config = described_class.disabled

      expect(config.disabled?).to be true
    end

    it "returns true when enabled is false" do
      config = described_class.new(
        enabled: false,
        max_size: 50,
        ttl_seconds: 1800,
        similarity_threshold: 0.9
      )

      expect(config.disabled?).to be true
    end

    it "returns false when enabled is true" do
      config = described_class.new(
        enabled: true,
        max_size: 50,
        ttl_seconds: 1800,
        similarity_threshold: 0.9
      )

      expect(config.disabled?).to be false
    end
  end

  describe "immutability" do
    it "is immutable via Data.define" do
      config = described_class.default

      expect { config.enabled = false }.to raise_error(NoMethodError)
    end

    it "supports with() for derived configs" do
      original = described_class.default
      updated = original.with(max_size: 200)

      expect(updated.max_size).to eq(200)
      expect(original.max_size).to eq(100)
    end
  end

  describe "custom configuration" do
    it "allows custom values" do
      config = described_class.new(
        enabled: true,
        max_size: 50,
        ttl_seconds: 1800,
        similarity_threshold: 0.9
      )

      expect(config.enabled).to be true
      expect(config.max_size).to eq(50)
      expect(config.ttl_seconds).to eq(1800)
      expect(config.similarity_threshold).to eq(0.9)
    end
  end
end
