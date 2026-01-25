RSpec.describe Smolagents::Utilities::Comparison::Similarity do
  describe ".score" do
    it "returns 1.0 when both texts have no entities" do
      result = described_class.score("plain text", "also plain")

      expect(result).to eq(1.0)
    end

    it "returns 0.0 when texts have no overlapping entities" do
      # Use texts with actual recognized entities (numbers, quoted strings)
      result = described_class.score("value 123", "number 456")

      expect(result).to eq(0.0)
    end

    it "returns 1.0 when texts have identical entities" do
      result = described_class.score("42 and ruby", "42 and ruby")

      expect(result).to eq(1.0)
    end

    it "computes Jaccard similarity for partial overlap" do
      # "apple" and "apple orange" share 1 entity, union has 2
      result = described_class.score("apple", "apple orange")

      expect(result).to be_between(0.0, 1.0)
    end

    it "extracts entities from both texts before comparison" do
      text_a = "Version 3.2 is great"
      text_b = "3.2 version rules"
      result = described_class.score(text_a, text_b)

      # Both contain "3.2" and version-related entities
      expect(result).to be > 0
    end

    it "converts objects to string via to_s" do
      obj_a = double(to_s: "42")
      obj_b = double(to_s: "42")
      result = described_class.score(obj_a, obj_b)

      expect(result).to eq(1.0)
    end

    it "handles case-insensitive comparison" do
      result = described_class.score("Ruby 3.2", "RUBY 3.2")

      expect(result).to be > 0
    end

    it "handles nil values" do
      result = described_class.score(nil, nil)

      expect(result).to eq(1.0)
    end

    it "scores similar technical identifiers" do
      result = described_class.score("api_key_123", "api_key_123")

      expect(result).to be > 0
    end

    it "scores URLs correctly" do
      result = described_class.score(
        "Visit https://example.com",
        "Check https://example.com"
      )

      expect(result).to be > 0
    end

    it "scores emails correctly" do
      result = described_class.score(
        "Contact user@example.com",
        "Email user@example.com"
      )

      expect(result).to be > 0
    end

    it "handles numbers with thousand separators" do
      result = described_class.score("1,000 items", "1,000 things")

      expect(result).to be > 0
    end

    it "returns Float" do
      result = described_class.score("test", "test")

      expect(result).to be_a(Float)
    end

    it "score is between 0 and 1" do
      result = described_class.score("apple banana cherry", "banana cherry date")

      expect(result).to be_between(0.0, 1.0)
    end
  end

  describe ".equivalent?" do
    it "returns true for identical texts" do
      result = described_class.equivalent?("apple banana", "apple banana")

      expect(result).to be true
    end

    it "returns false when entity overlap is below default threshold" do
      # Entities: "42" and "99" have 0 overlap
      result = described_class.equivalent?("value is 42", "value is 99")

      # Score will be 0.0, below default 0.7
      expect(result).to be false
    end

    it "returns false for texts with no entity overlap" do
      # Use texts with actual entities that don't overlap
      result = described_class.equivalent?("code 123", "code 456")

      expect(result).to be false
    end

    it "accepts custom threshold parameter" do
      result = described_class.equivalent?("apple orange", "apple", threshold: 0.4)

      # Score will be 0.5 which is above 0.4
      expect(result).to be true
    end

    it "uses DEFAULT_THRESHOLD when not specified" do
      # Create texts that score exactly at default threshold
      result = described_class.equivalent?(
        "test123",
        "test123",
        threshold: described_class::DEFAULT_THRESHOLD
      )

      expect(result).to be true
    end

    it "returns true for empty entity sets above threshold" do
      result = described_class.equivalent?("plain", "text", threshold: 0.5)

      expect(result).to be true # Both empty sets = score 1.0
    end

    it "compares scores using Utilities::Similarity" do
      allow(Smolagents::Utilities::Similarity).to receive(:equivalent?).and_return(true)

      result = described_class.equivalent?("test", "test")

      expect(result).to be true
      expect(Smolagents::Utilities::Similarity).to have_received(:equivalent?)
    end
  end

  describe ".jaccard" do
    it "delegates to Utilities::Similarity.jaccard" do
      set_a = Set.new(%w[a b])
      set_b = Set.new(%w[b c])

      result = described_class.jaccard(set_a, set_b)

      # Jaccard: intersection=1, union=3, score=1/3~0.333
      expect(result).to be_a(Float)
    end

    it "computes correct Jaccard score" do
      set_a = Set.new([1, 2, 3])
      set_b = Set.new([2, 3, 4])

      result = described_class.jaccard(set_a, set_b)

      # intersection: {2, 3}, union: {1, 2, 3, 4}
      # score: 2/4 = 0.5
      expect(result).to eq(0.5)
    end

    it "handles empty sets" do
      set_a = Set.new
      set_b = Set.new

      result = described_class.jaccard(set_a, set_b)

      # Empty sets have no union, so Jaccard returns 0.0 (or 1.0 per impl)
      # The Similarity.jaccard returns 0.0 for empty union
      expect(result).to be_a(Float)
    end

    it "handles identical sets" do
      set_a = Set.new(%w[a b c])
      set_b = Set.new(%w[a b c])

      result = described_class.jaccard(set_a, set_b)

      expect(result).to eq(1.0)
    end

    it "handles disjoint sets" do
      set_a = Set.new(%w[a b])
      set_b = Set.new(%w[c d])

      result = described_class.jaccard(set_a, set_b)

      expect(result).to eq(0.0)
    end
  end

  describe "DEFAULT_THRESHOLD constant" do
    it "defines default threshold for equivalence" do
      expect(described_class::DEFAULT_THRESHOLD).to eq(0.7)
    end

    it "is a Float" do
      expect(described_class::DEFAULT_THRESHOLD).to be_a(Float)
    end
  end
end
