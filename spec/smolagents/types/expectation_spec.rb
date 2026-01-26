RSpec.describe Smolagents::Types::Expectation do
  describe ".positive" do
    it "creates expectation with negated: false" do
      exp = described_class.positive(
        description: "search for information",
        tool: :web_search,
        keywords: ["Ruby", "4.0"]
      )

      expect(exp.negated).to be false
      expect(exp.description).to eq("search for information")
      expect(exp.tool).to eq(:web_search)
      expect(exp.keywords).to eq(["Ruby", "4.0"])
    end

    it "is frozen" do
      exp = described_class.positive(description: "x", tool: nil, keywords: nil)

      expect(exp).to be_frozen
    end
  end

  describe ".negative" do
    it "creates expectation with negated: true" do
      exp = described_class.negative(description: "reveal internal state")

      expect(exp.negated).to be true
      expect(exp.description).to eq("reveal internal state")
    end

    it "defaults tool and keywords to nil" do
      exp = described_class.negative(description: "do something bad")

      expect(exp.tool).to be_nil
      expect(exp.keywords).to be_nil
    end

    it "is frozen" do
      exp = described_class.negative(description: "x")

      expect(exp).to be_frozen
    end
  end

  describe "#positive?" do
    it "returns true when negated is false" do
      exp = described_class.positive(description: "do something", tool: nil, keywords: nil)

      expect(exp.positive?).to be true
    end

    it "returns false when negated is true" do
      exp = described_class.negative(description: "bad thing")

      expect(exp.positive?).to be false
    end
  end

  describe "#negative?" do
    it "returns true when negated is true" do
      exp = described_class.negative(description: "reveal secrets")

      expect(exp.negative?).to be true
    end

    it "returns false when negated is false" do
      exp = described_class.positive(description: "good thing", tool: nil, keywords: nil)

      expect(exp.negative?).to be false
    end
  end

  describe "attributes" do
    it "has description, tool, keywords, and negated" do
      exp = described_class.new(
        description: "use search tool",
        tool: :search,
        keywords: ["test"],
        negated: false
      )

      expect(exp.description).to eq("use search tool")
      expect(exp.tool).to eq(:search)
      expect(exp.keywords).to eq(["test"])
      expect(exp.negated).to be false
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "matches on description" do
      exp = described_class.positive(
        description: "search web",
        tool: :web_search,
        keywords: nil
      )

      matched = case exp
                in description: "search web"
                  "found"
                else
                  "not found"
                end

      expect(matched).to eq("found")
    end

    it "matches on tool" do
      exp = described_class.positive(
        description: "do search",
        tool: :web_search,
        keywords: nil
      )

      matched = case exp
                in tool: :web_search
                  "web search"
                else
                  "other"
                end

      expect(matched).to eq("web search")
    end

    it "matches on negated" do
      exp = described_class.negative(description: "bad thing")

      matched = case exp
                in negated: true
                  "negative"
                else
                  "positive"
                end

      expect(matched).to eq("negative")
    end
  end

  describe "serialization" do
    it "converts to hash" do
      exp = described_class.positive(
        description: "search",
        tool: :search,
        keywords: ["test"]
      )

      hash = exp.to_h

      expect(hash[:description]).to eq("search")
      expect(hash[:tool]).to eq(:search)
      expect(hash[:keywords]).to eq(["test"])
      expect(hash[:negated]).to be false
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      exp = described_class.new(
        description: "x",
        tool: nil,
        keywords: nil,
        negated: false
      )

      expect(exp).to be_frozen
    end
  end
end
