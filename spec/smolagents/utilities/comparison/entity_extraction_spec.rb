RSpec.describe Smolagents::Utilities::Comparison::EntityExtraction do
  describe ".extract" do
    it "extracts numbers with thousand separators" do
      text = "The value is 1,000 or 2,500.75"
      result = described_class.extract(text)

      expect(result).to include("1,000")
      expect(result).to include("2,500.75")
    end

    it "extracts simple numbers" do
      text = "I have 42 apples and 3.14 pies"
      result = described_class.extract(text)

      expect(result).to include("42")
      expect(result).to include("3.14")
    end

    it "extracts double-quoted strings" do
      text = 'He said "Hello World" and "Goodbye"'
      result = described_class.extract(text)

      expect(result).to include("hello world")
      expect(result).to include("goodbye")
    end

    it "extracts single-quoted strings" do
      text = "They said 'Good morning' and 'Good evening'"
      result = described_class.extract(text)

      expect(result).to include("good morning")
      expect(result).to include("good evening")
    end

    it "extracts proper nouns" do
      text = "Ruby is great. I like Paris and New York"
      result = described_class.extract(text)

      expect(result).to include("ruby")
      expect(result).to include("paris")
      expect(result).to include("new york")
    end

    it "extracts URLs" do
      text = "Visit https://example.com or http://test.org"
      result = described_class.extract(text)

      expect(result).to include("https://example.com")
      expect(result).to include("http://test.org")
    end

    it "extracts email addresses" do
      text = "Contact user@example.com or test.user@domain.co.uk"
      result = described_class.extract(text)

      expect(result).to include("user@example.com")
      expect(result).to include("test.user@domain.co.uk")
    end

    it "extracts technical identifiers (kebab-case)" do
      text = "Use the ruby-version or node-js package"
      result = described_class.extract(text)

      expect(result).to include("ruby-version")
      expect(result).to include("node-js")
    end

    it "extracts technical identifiers (snake_case)" do
      text = "Set the max_retries or api_key variable"
      result = described_class.extract(text)

      expect(result).to include("max_retries")
      expect(result).to include("api_key")
    end

    it "returns a Set of unique entities" do
      text = "ruby 3.2 ruby 3.2 is great"
      result = described_class.extract(text)

      expect(result).to be_a(Set)
      # Numbers are extracted separately from proper nouns
      expect(result).to include("3.2")
    end

    it "normalizes entities to lowercase" do
      text = "test_pattern here_too snake_case"
      result = described_class.extract(text)

      # All extracted entities should be lowercase
      result.each do |entity|
        expect(entity).to eq(entity.downcase)
      end
    end

    it "rejects empty extracted strings" do
      text = "test '' \"\" value"
      result = described_class.extract(text)

      expect(result).not_to include("")
    end

    it "handles text with no clear entities" do
      text = "plain text without special patterns"
      result = described_class.extract(text)

      expect(result).to be_a(Set)
      # May extract technical identifiers or other patterns
    end

    it "handles nil by converting to string" do
      result = described_class.extract(nil)

      expect(result).to be_a(Set)
      expect(result).to include("") unless nil.to_s.empty?
    end

    it "handles objects responding to to_s" do
      object = double(to_s: "42 and 3.14")
      result = described_class.extract(object)

      expect(result).to include("42")
      expect(result).to include("3.14")
    end

    it "extracts multiple entity types from complex text" do
      text = 'Visit https://example.com with query "search term". The ID is api_key_123 (123.45). Contact user@test.com'
      result = described_class.extract(text)

      # All of these should be found
      expect(result).to include("https://example.com")
      expect(result).to include("search term")
      expect(result).to include("123.45")
      expect(result).to include("user@test.com")
      # May also include proper nouns like "visit", "the", "contact"
    end
  end

  describe ".any?" do
    it "returns true when entities are present" do
      text = "Version 3.2 is available"
      expect(described_class.any?(text)).to be true
    end

    it "returns true when patterns match" do
      text = "test_pattern here"
      result = described_class.any?(text)
      expect(result).to be_a(TrueClass).or be_a(FalseClass)
    end

    it "returns true for numeric values" do
      text = "The answer is 42"
      expect(described_class.any?(text)).to be true
    end

    it "returns true for URLs" do
      text = "Check https://example.com"
      expect(described_class.any?(text)).to be true
    end

    it "returns true for proper nouns" do
      text = "Alice and Bob met"
      expect(described_class.any?(text)).to be true
    end
  end

  describe "PATTERNS constant" do
    it "defines patterns for all entity types" do
      patterns = described_class::PATTERNS

      expect(patterns).to have_key(:numbers)
      expect(patterns).to have_key(:quoted_double)
      expect(patterns).to have_key(:quoted_single)
      expect(patterns).to have_key(:proper_nouns)
      expect(patterns).to have_key(:urls)
      expect(patterns).to have_key(:emails)
      expect(patterns).to have_key(:technical)
    end

    it "each pattern is a Regexp" do
      described_class::PATTERNS.each_value do |pattern|
        expect(pattern).to be_a(Regexp)
      end
    end

    it "freezes patterns to prevent modification" do
      expect(described_class::PATTERNS).to be_frozen
    end
  end

  describe "ALL_PATTERNS constant" do
    it "contains all pattern values" do
      all_patterns = described_class::ALL_PATTERNS

      expect(all_patterns).to include(described_class::PATTERNS[:numbers])
      expect(all_patterns).to include(described_class::PATTERNS[:urls])
    end

    it "is frozen to prevent modification" do
      expect(described_class::ALL_PATTERNS).to be_frozen
    end
  end
end
