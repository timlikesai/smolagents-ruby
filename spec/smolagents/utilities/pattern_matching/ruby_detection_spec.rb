RSpec.describe Smolagents::Utilities::PatternMatching::RubyDetection do
  describe ".looks_like_ruby?" do
    it "detects def keyword" do
      code = "def hello\n  puts 'hi'\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects end keyword" do
      code = "class Test\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects puts" do
      code = "puts 'hello world'"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects print" do
      code = "print 'output'"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects variable assignment" do
      code = "x = 42"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects function calls" do
      code = "calculate(expression)"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects method calls with keyword arguments" do
      code = "search(query: 'test')"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects do blocks" do
      code = "[1,2,3].each do |x|\n  puts x\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects .each method" do
      code = "items.each { |i| puts i }"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects .map method" do
      code = "numbers.map { |n| n * 2 }"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects final_answer" do
      code = "final_answer(answer: 42)"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects result assignment" do
      code = "result = search(query)"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects calculate function" do
      code = "answer = calculate(expression: '2+2')"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects search function" do
      code = "results = search(query: 'Ruby')"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects return statement" do
      code = "def get_value\n  return 42\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects class definition" do
      code = "class Calculator\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects module definition" do
      code = "module Utils\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects require" do
      code = "require 'json'"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects nil literal" do
      code = "value = nil"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects true literal" do
      code = "enabled = true"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects false literal" do
      code = "disabled = false"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects empty array literal" do
      code = "items = []"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects empty hash literal" do
      code = "options = {}"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "detects arithmetic expressions" do
      code = "result = 10 + 20 * 5"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "rejects nil input" do
      expect(described_class.looks_like_ruby?(nil)).to be false
    end

    it "rejects empty string" do
      expect(described_class.looks_like_ruby?("")).to be false
    end

    it "rejects short strings" do
      expect(described_class.looks_like_ruby?("ab")).to be false
    end

    it "rejects prose text" do
      prose = "The quick brown fox jumps over the lazy dog in the morning light"
      expect(described_class.looks_like_ruby?(prose)).to be false
    end

    it "accepts code with prose inside strings" do
      code = %(puts "The quick brown fox jumps over the lazy dog")
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "rejects pure prose with no code indicators" do
      text = "Python is a high-level programming language designed for simplicity"
      expect(described_class.looks_like_ruby?(text)).to be false
    end

    it "accepts mixed code and short prose" do
      code = "# A function\ndef test\n  puts 'hi'\nend"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "handles method chaining" do
      code = "[1,2,3].map { |x| x * 2 }.select { |x| x > 2 }"
      expect(described_class.looks_like_ruby?(code)).to be true
    end

    it "handles multi-line code" do
      code = "def calculate(x, y)\n  x + y\nend\n\nresult = calculate(1, 2)"
      expect(described_class.looks_like_ruby?(code)).to be true
    end
  end

  describe ".prose_like?" do
    it "returns true for long prose with few code symbols" do
      prose = "The answer to this question is that we need to understand " \
              "the fundamental principles of mathematics before we can " \
              "calculate anything"
      expect(described_class.prose_like?(prose)).to be true
    end

    it "returns false for code with few words" do
      code = "x = 42"
      expect(described_class.prose_like?(code)).to be false
    end

    it "returns false for code with many symbols" do
      code = "def test; [1,2].map { |x| x + 1 }; end"
      expect(described_class.prose_like?(code)).to be false
    end

    it "ignores words in double quotes" do
      code = '"this is a long sentence in a string" x = 1'
      expect(described_class.prose_like?(code)).to be false
    end

    it "ignores words in single quotes" do
      code = "'another long sentence here' y = 2"
      expect(described_class.prose_like?(code)).to be false
    end

    it "counts unquoted words" do
      # Needs > 10 words with < 3 symbols to be prose-like
      code = "word word word word word word word word word word word x = 1"
      expect(described_class.prose_like?(code)).to be true
    end
  end

  describe "INDICATORS constant" do
    it "contains array of Regexp patterns" do
      indicators = described_class::INDICATORS

      expect(indicators).to be_an(Array)
      expect(indicators.length).to be > 0
      indicators.each { |ind| expect(ind).to be_a(Regexp) }
    end

    it "is frozen to prevent modification" do
      expect(described_class::INDICATORS).to be_frozen
    end

    it "includes common Ruby patterns" do
      indicators = described_class::INDICATORS

      patterns_str = indicators.map(&:to_s).join
      expect(patterns_str).to include("def")
      expect(patterns_str).to include("final_answer")
    end
  end
end
