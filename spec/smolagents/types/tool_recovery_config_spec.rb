require "spec_helper"

RSpec.describe Smolagents::Types::ToolRecoveryConfig do
  describe ".default" do
    subject(:config) { described_class.default }

    it "is enabled" do
      expect(config.enabled).to be true
    end

    it "has max_attempts of 3" do
      expect(config.max_attempts).to eq(3)
    end

    it "allows retry" do
      expect(config.allow_retry).to be true
    end

    it "allows reformat" do
      expect(config.allow_reformat).to be true
    end

    it "disallows switch by default" do
      expect(config.allow_switch).to be false
    end

    it "has empty fallback_tools" do
      expect(config.fallback_tools).to eq({})
    end

    it "is frozen" do
      expect(config).to be_frozen
    end
  end

  describe ".disabled" do
    subject(:config) { described_class.disabled }

    it "is not enabled" do
      expect(config.enabled).to be false
    end

    it "has max_attempts of 0" do
      expect(config.max_attempts).to eq(0)
    end

    it "disallows retry" do
      expect(config.allow_retry).to be false
    end

    it "disallows reformat" do
      expect(config.allow_reformat).to be false
    end

    it "disallows switch" do
      expect(config.allow_switch).to be false
    end

    it "is frozen" do
      expect(config).to be_frozen
    end
  end

  describe "#disabled?" do
    it "returns false when enabled" do
      expect(described_class.default.disabled?).to be false
    end

    it "returns true when disabled" do
      expect(described_class.disabled.disabled?).to be true
    end
  end

  describe "#can_retry?" do
    it "returns true when enabled and allow_retry is true" do
      expect(described_class.default.can_retry?).to be true
    end

    it "returns false when disabled" do
      expect(described_class.disabled.can_retry?).to be false
    end

    it "returns false when allow_retry is false" do
      config = described_class.new(
        enabled: true, max_attempts: 3, allow_retry: false,
        allow_reformat: true, allow_switch: false, fallback_tools: {}
      )
      expect(config.can_retry?).to be false
    end
  end

  describe "#can_reformat?" do
    it "returns true when enabled and allow_reformat is true" do
      expect(described_class.default.can_reformat?).to be true
    end

    it "returns false when disabled" do
      expect(described_class.disabled.can_reformat?).to be false
    end

    it "returns false when allow_reformat is false" do
      config = described_class.new(
        enabled: true, max_attempts: 3, allow_retry: true,
        allow_reformat: false, allow_switch: false, fallback_tools: {}
      )
      expect(config.can_reformat?).to be false
    end
  end

  describe "#can_switch?" do
    it "returns false when allow_switch is false" do
      expect(described_class.default.can_switch?).to be false
    end

    it "returns true when enabled and allow_switch is true" do
      config = described_class.new(
        enabled: true, max_attempts: 3, allow_retry: true,
        allow_reformat: true, allow_switch: true, fallback_tools: {}
      )
      expect(config.can_switch?).to be true
    end

    it "returns false when disabled" do
      expect(described_class.disabled.can_switch?).to be false
    end
  end

  describe "#fallback?" do
    it "returns false when no fallbacks configured" do
      expect(described_class.default.fallback?("search")).to be false
    end

    it "returns true when fallback exists for tool" do
      config = described_class.new(
        enabled: true, max_attempts: 3, allow_retry: true,
        allow_reformat: true, allow_switch: true,
        fallback_tools: { "search" => "web_search" }
      )
      expect(config.fallback?("search")).to be true
    end

    it "returns false for non-existent fallback" do
      config = described_class.new(
        enabled: true, max_attempts: 3, allow_retry: true,
        allow_reformat: true, allow_switch: true,
        fallback_tools: { "search" => "web_search" }
      )
      expect(config.fallback?("unknown")).to be false
    end
  end

  describe "#fallback_for" do
    it "returns nil when no fallback configured" do
      expect(described_class.default.fallback_for("search")).to be_nil
    end

    it "returns fallback tool name when configured" do
      config = described_class.new(
        enabled: true, max_attempts: 3, allow_retry: true,
        allow_reformat: true, allow_switch: true,
        fallback_tools: { "search" => "web_search" }
      )
      expect(config.fallback_for("search")).to eq("web_search")
    end
  end
end
