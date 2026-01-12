# frozen_string_literal: true

RSpec.describe Smolagents::ToolCollection do
  let(:tool1) do
    Smolagents::Tools.define_tool(
      :tool1,
      description: "First tool",
      inputs: {},
      output_type: "string"
    ) { "result1" }
  end

  let(:tool2) do
    Smolagents::Tools.define_tool(
      :tool2,
      description: "Second tool",
      inputs: {},
      output_type: "string"
    ) { "result2" }
  end

  describe "#initialize" do
    it "creates empty collection" do
      collection = described_class.new
      expect(collection).to be_empty
    end

    it "creates collection with tools" do
      collection = described_class.new([tool1, tool2])
      expect(collection.size).to eq(2)
    end
  end

  describe "#add / #<<" do
    it "adds tool to collection" do
      collection = described_class.new
      collection << tool1
      expect(collection.size).to eq(1)
    end
  end

  describe "#[]" do
    it "retrieves tool by name" do
      collection = described_class.new([tool1, tool2])
      expect(collection["tool1"]).to eq(tool1)
      expect(collection[:tool2]).to eq(tool2)
    end

    it "returns nil for non-existent tool" do
      collection = described_class.new([tool1])
      expect(collection["nonexistent"]).to be_nil
    end
  end

  describe "#names" do
    it "returns array of tool names" do
      collection = described_class.new([tool1, tool2])
      expect(collection.names).to contain_exactly("tool1", "tool2")
    end
  end

  describe "#include?" do
    it "checks if tool exists" do
      collection = described_class.new([tool1])
      expect(collection.include?("tool1")).to be true
      expect(collection.include?(:tool1)).to be true
      expect(collection.include?("tool2")).to be false
    end
  end

  describe "#remove" do
    it "removes tool by name" do
      collection = described_class.new([tool1, tool2])
      removed = collection.remove("tool1")
      expect(removed).to eq(tool1)
      expect(collection.size).to eq(1)
      expect(collection.include?("tool1")).to be false
    end
  end

  describe "#each" do
    it "iterates over tools" do
      collection = described_class.new([tool1, tool2])
      names = []
      collection.each { |tool| names << tool.name }
      expect(names).to contain_exactly("tool1", "tool2")
    end
  end

  describe ".from_tools" do
    it "creates collection from array" do
      collection = described_class.from_tools([tool1, tool2])
      expect(collection.size).to eq(2)
    end
  end

  describe ".from_hash" do
    it "creates collection from hash" do
      hash = { "tool1" => tool1, "tool2" => tool2 }
      collection = described_class.from_hash(hash)
      expect(collection.size).to eq(2)
    end
  end
end
