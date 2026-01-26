RSpec.describe Smolagents::Types::Capability do
  describe "attributes" do
    it "has tool and description" do
      cap = described_class.new(tool: :search_web, description: "find information online")

      expect(cap.tool).to eq(:search_web)
      expect(cap.description).to eq("find information online")
    end

    it "allows nil description" do
      cap = described_class.new(tool: :calculate, description: nil)

      expect(cap.tool).to eq(:calculate)
      expect(cap.description).to be_nil
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "matches on tool" do
      cap = described_class.new(tool: :web_search, description: "search the web")

      matched = case cap
                in tool: :web_search
                  "web search capability"
                else
                  "other"
                end

      expect(matched).to eq("web search capability")
    end

    it "matches on description" do
      cap = described_class.new(tool: :fetch, description: "fetch URL content")

      matched = case cap
                in description: "fetch URL content"
                  "fetcher"
                else
                  "other"
                end

      expect(matched).to eq("fetcher")
    end

    it "matches both fields" do
      cap = described_class.new(tool: :read_file, description: "read file contents")

      matched = case cap
                in tool: :read_file, description: "read file contents"
                  "exact match"
                else
                  "no match"
                end

      expect(matched).to eq("exact match")
    end
  end

  describe "serialization" do
    it "converts to hash" do
      cap = described_class.new(tool: :search, description: "search things")

      hash = cap.to_h

      expect(hash).to eq({ tool: :search, description: "search things" })
    end

    it "includes nil values" do
      cap = described_class.new(tool: :calc, description: nil)

      hash = cap.to_h

      expect(hash).to eq({ tool: :calc, description: nil })
    end
  end

  describe "immutability" do
    it "is frozen" do
      cap = described_class.new(tool: :search, description: "search")

      expect(cap).to be_frozen
    end
  end
end
