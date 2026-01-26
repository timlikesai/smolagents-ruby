require "spec_helper"

RSpec.describe Smolagents::Persistence::AgentManifestConstants do
  describe "VERSION" do
    it "is a frozen string" do
      expect(described_class::VERSION).to be_frozen
      expect(described_class::VERSION).to eq("1.0")
    end
  end

  describe "ALLOWED_CLASSES" do
    it "is a frozen set" do
      expect(described_class::ALLOWED_CLASSES).to be_frozen
      expect(described_class::ALLOWED_CLASSES).to be_a(Set)
    end

    it "includes Agent class" do
      expect(described_class::ALLOWED_CLASSES).to include("Smolagents::Agents::Agent")
    end

    it "does not allow arbitrary classes" do
      expect(described_class::ALLOWED_CLASSES).not_to include("Kernel")
      expect(described_class::ALLOWED_CLASSES).not_to include("Object")
    end
  end

  describe "REQUIRED_FIELDS" do
    it "is a frozen array of symbols" do
      expect(described_class::REQUIRED_FIELDS).to be_frozen
      expect(described_class::REQUIRED_FIELDS).to all(be_a(Symbol))
    end

    it "includes version, agent_class, and model" do
      expect(described_class::REQUIRED_FIELDS).to include(:version, :agent_class, :model)
    end
  end

  describe "EXTRACTABLE_FIELDS" do
    it "is a frozen hash" do
      expect(described_class::EXTRACTABLE_FIELDS).to be_frozen
    end

    it "maps config keys to agent attributes" do
      expect(described_class::EXTRACTABLE_FIELDS[:max_steps]).to eq(:max_steps)
      expect(described_class::EXTRACTABLE_FIELDS[:planning_interval]).to eq(:planning_interval)
      expect(described_class::EXTRACTABLE_FIELDS[:custom_instructions]).to eq(:@custom_instructions)
    end

    it "uses symbols starting with @ for instance variables" do
      ivar_sources = described_class::EXTRACTABLE_FIELDS.values.select { it.to_s.start_with?("@") }

      expect(ivar_sources).to include(:@custom_instructions)
    end
  end
end
