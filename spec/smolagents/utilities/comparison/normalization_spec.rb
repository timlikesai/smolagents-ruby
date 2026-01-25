RSpec.describe Smolagents::Utilities::Comparison::Normalization do
  describe ".normalize" do
    it "converts text to lowercase" do
      result = described_class.normalize("HELLO World")

      expect(result).to eq("hello world")
    end

    it "removes punctuation" do
      result = described_class.normalize("Hello, World!")

      expect(result).to eq("hello world")
    end

    it "removes special characters" do
      result = described_class.normalize("test@#$%example")

      expect(result).to eq("test example")
    end

    it "collapses multiple spaces into single space" do
      result = described_class.normalize("hello    world")

      expect(result).to eq("hello world")
    end

    it "collapses tabs and newlines to spaces" do
      result = described_class.normalize("hello\t\n\t  world")

      expect(result).to eq("hello world")
    end

    it "strips leading and trailing whitespace" do
      result = described_class.normalize("   hello world   ")

      expect(result).to eq("hello world")
    end

    it "preserves underscores and word characters" do
      result = described_class.normalize("snake_case_word")

      expect(result).to eq("snake_case_word")
    end

    it "preserves numbers" do
      result = described_class.normalize("version3.2")

      expect(result).to eq("version3 2")
    end

    it "removes quotes" do
      result = described_class.normalize('"quoted text"')

      expect(result).to eq("quoted text")
    end

    it "removes hyphens and dashes" do
      result = described_class.normalize("multi-word-phrase")

      expect(result).to eq("multi word phrase")
    end

    it "handles mixed case and special characters" do
      result = described_class.normalize("Hello-World!!!123")

      expect(result).to eq("hello world 123")
    end

    it "handles parentheses" do
      result = described_class.normalize("function(arg1, arg2)")

      expect(result).to eq("function arg1 arg2")
    end

    it "handles slashes and backslashes" do
      result = described_class.normalize("path/to/file\\backup")

      expect(result).to eq("path to file backup")
    end

    it "handles dots" do
      result = described_class.normalize("example.com.test")

      expect(result).to eq("example com test")
    end

    it "converts nil to string first" do
      result = described_class.normalize(nil)

      expect(result).to eq("")
    end

    it "converts objects with to_s method" do
      obj = double(to_s: "Example Text!")
      result = described_class.normalize(obj)

      expect(result).to eq("example text")
    end

    it "handles empty string" do
      result = described_class.normalize("")

      expect(result).to eq("")
    end

    it "handles whitespace-only string" do
      result = described_class.normalize("   \t\n  ")

      expect(result).to eq("")
    end

    it "preserves digits in text" do
      result = described_class.normalize("Test123ABC")

      expect(result).to eq("test123abc")
    end

    it "normalizes complex example" do
      complex = "Ruby 3.2 (Released: 2022-12-25) - A Great Language!"
      result = described_class.normalize(complex)

      expect(result).to eq("ruby 3 2 released 2022 12 25 a great language")
    end

    it "is idempotent" do
      text = "Hello, World!"
      once = described_class.normalize(text)
      twice = described_class.normalize(once)

      expect(twice).to eq(once)
    end
  end
end
