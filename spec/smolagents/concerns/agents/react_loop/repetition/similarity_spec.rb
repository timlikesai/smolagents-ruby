RSpec.describe Smolagents::Concerns::ReActLoop::Repetition::Similarity do
  let(:instance) do
    Class.new { include Smolagents::Concerns::ReActLoop::Repetition::Similarity }.new
  end

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(:string_similarity, :trigrams)
    end
  end

  describe "#string_similarity" do
    it "returns 1.0 for identical strings" do
      similarity = instance.send(:string_similarity, "hello world", "hello world")
      expect(similarity).to eq(1.0)
    end

    it "returns 0.0 for empty first string" do
      expect(instance.send(:string_similarity, "", "hello")).to eq(0.0)
    end

    it "returns 0.0 for empty second string" do
      expect(instance.send(:string_similarity, "hello", "")).to eq(0.0)
    end

    it "returns high similarity for nearly identical strings" do
      similarity = instance.send(:string_similarity, "hello world", "hello world!")
      expect(similarity).to be > 0.8
    end

    it "returns low similarity for very different strings" do
      similarity = instance.send(:string_similarity, "hello world", "xyz abc 123")
      expect(similarity).to be < 0.3
    end

    it "handles short strings gracefully" do
      similarity = instance.send(:string_similarity, "ab", "ab")
      expect(similarity).to eq(1.0)
    end

    it "handles single character strings" do
      similarity = instance.send(:string_similarity, "a", "b")
      expect(similarity).to eq(0.0)
    end
  end

  describe "#trigrams" do
    it "extracts character trigrams from a string" do
      result = instance.send(:trigrams, "hello")
      expect(result).to be_a(Set)
      expect(result).to include("hel", "ell", "llo")
      expect(result.size).to eq(3)
    end

    it "returns empty set for strings shorter than 3 characters" do
      expect(instance.send(:trigrams, "ab")).to eq(Set.new)
      expect(instance.send(:trigrams, "a")).to eq(Set.new)
      expect(instance.send(:trigrams, "")).to eq(Set.new)
    end

    it "handles exactly 3 character strings" do
      result = instance.send(:trigrams, "abc")
      expect(result).to eq(Set.new(["abc"]))
    end
  end
end
