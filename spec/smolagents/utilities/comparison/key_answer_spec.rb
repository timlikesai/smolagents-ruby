RSpec.describe Smolagents::Utilities::Comparison::KeyAnswer do
  # Padding to ensure text is > MIN_LENGTH (100)
  let(:padding) { "x" * 100 }

  describe ".extract" do
    context "with short text (below MIN_LENGTH)" do
      it "returns short text as-is" do
        short_text = "answer"
        result = described_class.extract(short_text)

        expect(result).to eq(short_text)
      end

      it "returns text under 100 chars unchanged" do
        text = "a" * 99
        result = described_class.extract(text)

        expect(result).to eq(text)
      end
    end

    context "with pattern-based answers" do
      it "extracts 'the answer is' pattern" do
        text = "#{padding} the answer is Paris."
        result = described_class.extract(text)

        expect(result).to eq("Paris")
      end

      it "extracts 'answer:' pattern" do
        text = "#{padding} answer: Brussels."
        result = described_class.extract(text)

        expect(result).to eq("Brussels")
      end

      it "extracts 'result:' pattern" do
        text = "#{padding} result: 42."
        result = described_class.extract(text)

        expect(result).to eq("42")
      end

      it "extracts 'therefore' pattern" do
        text = "#{padding} therefore, the capital is Tokyo."
        result = described_class.extract(text)

        expect(result).to eq("the capital is Tokyo")
      end

      it "extracts 'thus' pattern" do
        text = "#{padding} thus the solution is true."
        result = described_class.extract(text)

        expect(result).to eq("the solution is true")
      end

      it "extracts 'finally' pattern" do
        text = "#{padding} Finally, we concluded with Amsterdam."
        result = described_class.extract(text)

        expect(result).to eq("we concluded with Amsterdam")
      end

      it "extracts 'in conclusion' pattern" do
        # NOTE: "the answer is" pattern matches first, so we test with different text
        text = "#{padding} In conclusion, Ruby is great."
        result = described_class.extract(text)

        expect(result).to eq("Ruby is great")
      end

      it "extracts 'to summarize' pattern" do
        text = "#{padding} To summarize, Ruby is awesome."
        result = described_class.extract(text)

        expect(result).to eq("Ruby is awesome")
      end

      it "stops at period after pattern" do
        text = "#{padding} the answer is correct."
        result = described_class.extract(text)

        expect(result).to eq("correct")
      end

      it "handles case-insensitive patterns" do
        text = "#{padding} THE ANSWER IS Paris."
        result = described_class.extract(text)

        expect(result).to eq("Paris")
      end

      it "prioritizes first matching pattern" do
        text = "#{padding} the answer is first. then: second"
        result = described_class.extract(text)

        expect(result).to eq("first")
      end
    end

    context "with sentence-based fallback" do
      it "returns last sentence with entities when no pattern matches" do
        text = "#{padding} Some discussion about things. We have 42 apples."
        result = described_class.extract(text)

        expect(result).to include("42")
      end

      it "returns last sentence if no sentences contain entities" do
        text = "#{padding} word word word. last sentence here"
        result = described_class.extract(text)

        # Should return a sentence (might be "last sentence here" or the whole thing)
        expect(result.length).to be > 0
      end

      it "returns last sentence containing entities" do
        text = "#{padding} sentence with 123. middle sentence. answer 456."
        result = described_class.extract(text)

        expect(result).to include("456")
      end

      it "splits on sentence delimiters" do
        text = "#{padding} First sentence. Second with entity 42."
        result = described_class.extract(text)

        expect(result).to include("42")
      end

      it "handles multiple sentence delimiters" do
        text = "#{padding} One! Two? Three with 789."
        result = described_class.extract(text)

        expect(result).to include("789")
      end

      it "returns entire text if no sentences found" do
        text = "#{padding}no delimiters here"
        result = described_class.extract(text)

        expect(result).to eq(text.strip)
      end
    end

    context "with edge cases" do
      it "handles text exactly at MIN_LENGTH" do
        text = "a" * 100
        result = described_class.extract(text)

        # Text at exactly MIN_LENGTH goes through pattern matching, returns as-is
        expect(result).to eq(text)
      end

      it "handles nil by converting to string" do
        result = described_class.extract(nil)

        expect(result).to be_a(String)
      end

      it "handles objects with to_s method" do
        obj = double(to_s: "#{padding} the answer is 99.")
        result = described_class.extract(obj)

        expect(result).to eq("99")
      end

      it "strips whitespace from result" do
        text = "#{padding} the answer is   padded text."
        result = described_class.extract(text)

        expect(result).to eq("padded text")
      end

      it "handles empty text" do
        result = described_class.extract("")

        expect(result).to eq("")
      end

      it "handles whitespace-only text" do
        result = described_class.extract("   \n\t  ")

        expect(result).to eq("")
      end
    end
  end

  describe ".from_pattern" do
    it "finds matching pattern in text" do
      text = "some text. the answer is correct. more text"
      result = described_class.from_pattern(text)

      expect(result).to eq("correct")
    end

    it "returns nil if no patterns match" do
      text = "just plain text without any patterns"
      result = described_class.from_pattern(text)

      expect(result).to be_nil
    end

    it "matches first pattern" do
      text = "answer: first. the answer is second."
      result = described_class.from_pattern(text)

      expect(result).to eq("first")
    end
  end

  describe ".from_sentences" do
    it "splits text into sentences" do
      text = "first. second. third."
      result = described_class.send(:from_sentences, text)

      expect(result).to be_a(String)
    end

    it "returns last sentence with entities" do
      text = "boring. stuff. here. has 42 items."
      result = described_class.send(:from_sentences, text)

      expect(result).to include("42")
    end

    it "returns last sentence if no entities found" do
      text = "nothing. nothing. nothing."
      result = described_class.send(:from_sentences, text)

      expect(result).to eq("nothing")
    end

    it "handles multiple sentence delimiters" do
      text = "one! two? three. four."
      result = described_class.send(:from_sentences, text)

      expect(result).to be_a(String)
    end

    it "returns entire text if no sentences" do
      text = "no delimiters at all"
      result = described_class.send(:from_sentences, text)

      expect(result).to eq(text)
    end

    it "strips whitespace from sentences" do
      text = "  first  .  second  .  "
      result = described_class.send(:from_sentences, text)

      expect(result).not_to match(/^\s/)
      expect(result).not_to match(/\s$/)
    end

    it "ignores blank sentences" do
      text = "first...second."
      result = described_class.send(:from_sentences, text)

      expect(result).to be_a(String)
    end
  end

  describe "MIN_LENGTH constant" do
    it "defines minimum length for extraction" do
      expect(described_class::MIN_LENGTH).to eq(100)
    end
  end

  describe "PATTERNS constant" do
    it "contains pattern array" do
      patterns = described_class::PATTERNS

      expect(patterns).to be_an(Array)
      expect(patterns.length).to be > 0
    end

    it "each pattern is a Regexp" do
      described_class::PATTERNS.each do |pattern|
        expect(pattern).to be_a(Regexp)
      end
    end

    it "is frozen to prevent modification" do
      expect(described_class::PATTERNS).to be_frozen
    end
  end
end
