require "smolagents"

RSpec.describe Smolagents::Utilities::Comparison do
  describe ".extract_entities" do
    it "extracts numbers" do
      entities = described_class.extract_entities("The answer is 42 and 3.14")
      expect(entities).to include("42", "3.14")
    end

    it "extracts numbers with commas" do
      entities = described_class.extract_entities("Population: 1,234,567")
      expect(entities).to include("1,234,567")
    end

    it "extracts double-quoted strings" do
      entities = described_class.extract_entities('The name is "John Doe"')
      expect(entities).to include("john doe")
    end

    it "extracts single-quoted strings" do
      entities = described_class.extract_entities("The color is 'blue'")
      expect(entities).to include("blue")
    end

    it "extracts proper nouns" do
      entities = described_class.extract_entities("Paris is the capital of France")
      expect(entities).to include("paris", "france")
    end

    it "extracts URLs" do
      entities = described_class.extract_entities("Visit https://example.com/page")
      expect(entities).to include("https://example.com/page")
    end

    it "extracts emails" do
      entities = described_class.extract_entities("Contact user@example.com")
      expect(entities).to include("user@example.com")
    end

    it "extracts kebab-case terms" do
      entities = described_class.extract_entities("Use the my-cool-package library")
      expect(entities).to include("my-cool-package")
    end

    it "returns empty set for empty text" do
      expect(described_class.extract_entities("")).to be_empty
    end

    it "normalizes to lowercase" do
      entities = described_class.extract_entities("PARIS and Paris")
      expect(entities.size).to eq(1)
      expect(entities).to include("paris")
    end
  end

  describe ".similarity" do
    it "returns 1.0 for identical texts" do
      expect(described_class.similarity("Paris is great", "Paris is great")).to eq(1.0)
    end

    it "returns 1.0 for both empty texts" do
      expect(described_class.similarity("", "")).to eq(1.0)
    end

    it "returns 0.0 for completely different texts" do
      expect(described_class.similarity("Paris France", "Tokyo Japan")).to eq(0.0)
    end

    it "returns partial similarity for overlapping entities" do
      similarity = described_class.similarity(
        "The capital of France is Paris",
        "Paris is a beautiful city in France"
      )
      expect(similarity).to be > 0.3
      expect(similarity).to be < 1.0
    end

    it "handles non-string inputs" do
      expect(described_class.similarity(42, 42)).to eq(1.0)
    end
  end

  describe ".equivalent?" do
    it "returns true for similar answers" do
      expect(described_class.equivalent?(
               "The answer is 42",
               "42 is the answer",
               threshold: 0.5
             )).to be true
    end

    it "returns false for different answers" do
      expect(described_class.equivalent?(
               "Paris",
               "London",
               threshold: 0.5
             )).to be false
    end

    it "uses default threshold of 0.7" do
      expect(described_class.equivalent?("Paris is great", "Paris is wonderful")).to be true
    end
  end

  describe ".normalize" do
    it "lowercases text" do
      expect(described_class.normalize("HELLO World")).to eq("hello world")
    end

    it "removes punctuation" do
      expect(described_class.normalize("Hello, World!")).to eq("hello world")
    end

    it "collapses whitespace" do
      expect(described_class.normalize("hello   world")).to eq("hello world")
    end

    it "strips leading/trailing whitespace" do
      expect(described_class.normalize("  hello  ")).to eq("hello")
    end
  end

  describe ".extract_key_answer" do
    it "returns short text unchanged" do
      expect(described_class.extract_key_answer("42")).to eq("42")
    end

    it "extracts from 'the answer is' pattern" do
      text = "After careful analysis, the answer is Paris."
      expect(described_class.extract_key_answer(text)).to include("Paris")
    end

    it "extracts from 'therefore' pattern" do
      text = "Based on my research, therefore, 42 degrees is correct."
      expect(described_class.extract_key_answer(text)).to include("42")
    end

    it "falls back to last sentence with entities" do
      text = "Let me think about this. I need to consider many factors. The capital is Paris."
      expect(described_class.extract_key_answer(text)).to include("Paris")
    end
  end

  describe ".group_similar" do
    it "groups identical answers" do
      answers = %w[Paris Paris Paris London]
      groups = described_class.group_similar(answers)

      expect(groups.first).to eq(%w[Paris Paris Paris])
      expect(groups.last).to eq(%w[London])
    end

    it "groups similar answers" do
      answers = [
        "The capital is Paris",
        "Paris is the capital",
        "London is great"
      ]
      groups = described_class.group_similar(answers, threshold: 0.5)

      expect(groups.size).to eq(2)
      expect(groups.first.size).to eq(2)
    end

    it "sorts groups by size descending" do
      answers = ["Paris 42", "Paris 42", "Paris 42", "London 99", "London 99", "Tokyo 7"]
      groups = described_class.group_similar(answers)

      expect(groups.first.size).to eq(3)
      expect(groups[1].size).to eq(2)
      expect(groups.last.size).to eq(1)
    end

    it "returns empty array for empty input" do
      expect(described_class.group_similar([])).to eq([])
    end
  end
end
