require "spec_helper"

RSpec.describe Smolagents::Types::RepetitionResult do
  describe ".none" do
    subject(:result) { described_class.none }

    it "has detected false" do
      expect(result.detected).to be false
    end

    it "has nil pattern" do
      expect(result.pattern).to be_nil
    end

    it "has zero count" do
      expect(result.count).to eq(0)
    end

    it "has nil guidance" do
      expect(result.guidance).to be_nil
    end

    it "responds to none? with true" do
      expect(result.none?).to be true
    end

    it "responds to detected? with false" do
      expect(result.detected?).to be false
    end
  end

  describe ".detected" do
    subject(:result) do
      described_class.detected(
        pattern: :tool_call,
        count: 3,
        guidance: "Try a different approach"
      )
    end

    it "has detected true" do
      expect(result.detected).to be true
    end

    it "has the specified pattern" do
      expect(result.pattern).to eq(:tool_call)
    end

    it "has the specified count" do
      expect(result.count).to eq(3)
    end

    it "has the specified guidance" do
      expect(result.guidance).to eq("Try a different approach")
    end

    it "responds to none? with false" do
      expect(result.none?).to be false
    end

    it "responds to detected? with true" do
      expect(result.detected?).to be true
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(described_class.none).to be_frozen
    end
  end
end

RSpec.describe Smolagents::Types::RepetitionConfig do
  describe ".default" do
    subject(:config) { described_class.default }

    it "has window_size of 3" do
      expect(config.window_size).to eq(3)
    end

    it "has similarity_threshold of 0.9" do
      expect(config.similarity_threshold).to eq(0.9)
    end

    it "has enabled true" do
      expect(config.enabled).to be true
    end
  end

  describe "custom configuration" do
    subject(:config) do
      described_class.new(
        window_size: 5,
        similarity_threshold: 0.85,
        enabled: false
      )
    end

    it "uses custom window_size" do
      expect(config.window_size).to eq(5)
    end

    it "uses custom similarity_threshold" do
      expect(config.similarity_threshold).to eq(0.85)
    end

    it "uses custom enabled" do
      expect(config.enabled).to be false
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(described_class.default).to be_frozen
    end
  end
end
