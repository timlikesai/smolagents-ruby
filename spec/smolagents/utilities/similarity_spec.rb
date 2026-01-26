RSpec.describe Smolagents::Utilities::Similarity do
  describe ".jaccard" do
    it "returns 1.0 for identical sets" do
      result = described_class.jaccard(Set["a", "b"], Set["a", "b"])

      expect(result).to eq(1.0)
    end

    it "returns 0.0 for disjoint sets" do
      result = described_class.jaccard(Set["a", "b"], Set["c", "d"])

      expect(result).to eq(0.0)
    end

    it "calculates partial overlap correctly" do
      result = described_class.jaccard(Set["a", "b"], Set["b", "c"])

      expect(result).to be_within(0.01).of(0.333)
    end

    it "accepts arrays as input" do
      result = described_class.jaccard(%w[a b], %w[b c])

      expect(result).to be_within(0.01).of(0.333)
    end

    it "returns 1.0 for two empty sets" do
      result = described_class.jaccard(Set[], Set[])

      expect(result).to eq(1.0)
    end

    it "returns 0.0 when one set is empty" do
      result = described_class.jaccard(Set["a"], Set[])

      expect(result).to eq(0.0)
    end
  end

  describe ".string" do
    it "returns 1.0 for identical strings" do
      result = described_class.string("hello", "hello")

      expect(result).to eq(1.0)
    end

    it "returns 0.0 for completely different strings" do
      result = described_class.string("abc", "xyz")

      expect(result).to eq(0.0)
    end

    it "returns high similarity for similar strings" do
      result = described_class.string("hello world", "hello world!")

      expect(result).to be > 0.8
    end

    it "returns 0.0 when one string is empty" do
      expect(described_class.string("", "hello")).to eq(0.0)
      expect(described_class.string("hello", "")).to eq(0.0)
    end

    it "returns 1.0 when both strings are identical (including empty)" do
      expect(described_class.string("", "")).to eq(1.0)
    end

    it "returns 0.0 for strings too short for trigrams" do
      expect(described_class.string("ab", "cd")).to eq(0.0)
    end

    it "handles nil by converting to empty string" do
      expect(described_class.string(nil, "hello")).to eq(0.0)
      expect(described_class.string("hello", nil)).to eq(0.0)
    end
  end

  describe ".trigrams" do
    it "extracts character trigrams" do
      result = described_class.trigrams("hello")

      expect(result).to eq(Set["hel", "ell", "llo"])
    end

    it "returns empty set for short strings" do
      expect(described_class.trigrams("ab")).to eq(Set[])
      expect(described_class.trigrams("")).to eq(Set[])
    end

    it "accepts custom n-gram size" do
      result = described_class.trigrams("hello", size: 2)

      expect(result).to eq(Set["he", "el", "ll", "lo"])
    end

    it "handles single character strings" do
      expect(described_class.trigrams("a")).to eq(Set[])
    end

    it "handles nil input" do
      expect(described_class.trigrams(nil)).to eq(Set[])
    end
  end

  describe ".terms" do
    it "returns 1.0 for identical texts" do
      result = described_class.terms("hello world", "hello world")

      expect(result).to eq(1.0)
    end

    it "ignores case differences" do
      result = described_class.terms("Hello World", "hello world")

      expect(result).to eq(1.0)
    end

    it "filters short words by default (min_length: 3)" do
      result = described_class.terms("a b c foo", "a b c bar")

      expect(result).to eq(0.0)
    end

    it "accepts custom min_length" do
      result = described_class.terms("ab cd", "ab cd", min_length: 2)

      expect(result).to eq(1.0)
    end

    it "returns 1.0 for both texts having no valid terms" do
      result = described_class.terms("a b", "c d")

      expect(result).to eq(1.0)
    end

    it "calculates partial overlap" do
      result = described_class.terms("ruby rails postgres", "ruby rails mongodb")

      expect(result).to be_within(0.01).of(0.5)
    end
  end

  describe ".extract_terms" do
    it "extracts lowercase words" do
      result = described_class.extract_terms("Hello World")

      expect(result).to eq(Set["hello", "world"])
    end

    it "filters by min_length" do
      result = described_class.extract_terms("a bc def ghij", min_length: 3)

      expect(result).to eq(Set["def", "ghij"])
    end

    it "handles punctuation" do
      result = described_class.extract_terms("Hello, world! How are you?")

      expect(result).to eq(Set["hello", "world", "how", "are", "you"])
    end

    it "handles empty input" do
      expect(described_class.extract_terms("")).to eq(Set[])
      expect(described_class.extract_terms(nil)).to eq(Set[])
    end
  end

  describe ".equivalent?" do
    it "returns true when score meets threshold" do
      expect(described_class.equivalent?(0.7)).to be(true)
      expect(described_class.equivalent?(0.9)).to be(true)
      expect(described_class.equivalent?(1.0)).to be(true)
    end

    it "returns false when score below threshold" do
      expect(described_class.equivalent?(0.69)).to be(false)
      expect(described_class.equivalent?(0.5)).to be(false)
      expect(described_class.equivalent?(0.0)).to be(false)
    end

    it "accepts custom threshold" do
      expect(described_class.equivalent?(0.5, threshold: 0.5)).to be(true)
      expect(described_class.equivalent?(0.5, threshold: 0.6)).to be(false)
    end
  end
end
