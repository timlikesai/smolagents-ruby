require "spec_helper"

RSpec.describe Smolagents::Testing::Validators do
  describe ".contains" do
    subject(:validator) { described_class.contains("Ruby") }

    it "returns true when text is present" do
      expect(validator.call("I love Ruby")).to be true
    end

    it "returns false when text is absent" do
      expect(validator.call("I love Python")).to be false
    end

    it "handles nil input" do
      expect(validator.call(nil)).to be false
    end

    it "handles non-string input" do
      expect(validator.call(123)).to be false
    end

    it "is case-sensitive" do
      expect(validator.call("ruby")).to be false
    end
  end

  describe ".matches" do
    subject(:validator) { described_class.matches(/\d+\.\d+/) }

    it "returns true when pattern matches" do
      expect(validator.call("Version 4.0")).to be true
    end

    it "returns false when pattern does not match" do
      expect(validator.call("No version here")).to be false
    end

    it "handles nil input" do
      expect(validator.call(nil)).to be false
    end

    it "handles complex patterns" do
      email_validator = described_class.matches(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
      expect(email_validator.call("test@example.com")).to be true
      expect(email_validator.call("invalid")).to be false
    end
  end

  describe ".equals" do
    subject(:validator) { described_class.equals("hello world") }

    it "returns true when strings are equal" do
      expect(validator.call("hello world")).to be true
    end

    it "returns false when strings differ" do
      expect(validator.call("hello")).to be false
    end

    it "strips whitespace before comparison" do
      expect(validator.call("  hello world  ")).to be true
    end

    it "handles nil input" do
      expect(validator.call(nil)).to be false
    end

    it "handles non-string expected values" do
      numeric_validator = described_class.equals(42)
      expect(numeric_validator.call("42")).to be true
    end
  end

  describe ".numeric_equals" do
    subject(:validator) { described_class.numeric_equals(42.0) }

    it "returns true when number matches exactly" do
      expect(validator.call("The answer is 42")).to be true
    end

    it "returns true within default tolerance" do
      expect(validator.call("The answer is 42.005")).to be true
    end

    it "returns false outside default tolerance" do
      expect(validator.call("The answer is 42.1")).to be false
    end

    it "handles custom tolerance" do
      loose_validator = described_class.numeric_equals(42.0, tolerance: 1.0)
      expect(loose_validator.call("The answer is 42.5")).to be true
    end

    it "extracts first number from text" do
      expect(validator.call("42 is the answer, not 100")).to be true
    end

    it "handles negative numbers" do
      negative_validator = described_class.numeric_equals(-10.0)
      expect(negative_validator.call("Temperature: -10 degrees")).to be true
    end

    it "returns false when no number present" do
      expect(validator.call("no numbers here")).to be false
    end

    it "handles decimal numbers" do
      decimal_validator = described_class.numeric_equals(3.14, tolerance: 0.01)
      expect(decimal_validator.call("Pi is approximately 3.14159")).to be true
    end
  end

  describe ".code_block?" do
    subject(:validator) { described_class.code_block? }

    it "returns true for ruby code block" do
      output = "Here is code:\n```ruby\nputs 'hello'\n```"
      expect(validator.call(output)).to be true
    end

    it "returns true for generic code block" do
      output = "Here is code:\n```\nputs 'hello'\n```"
      expect(validator.call(output)).to be true
    end

    it "returns false for inline code" do
      expect(validator.call("Use `puts` to print")).to be false
    end

    it "returns false for no code block" do
      expect(validator.call("No code here")).to be false
    end

    it "returns false for empty code block" do
      output = "Empty:\n```ruby\n```"
      expect(validator.call(output)).to be false
    end
  end

  describe ".calls_tool" do
    subject(:validator) { described_class.calls_tool(:search) }

    it "returns true when tool call is present" do
      expect(validator.call("search(query: 'Ruby')")).to be true
    end

    it "returns false when tool call is absent" do
      expect(validator.call("final_answer(answer: 'done')")).to be false
    end

    it "handles string tool names" do
      string_validator = described_class.calls_tool("web_search")
      expect(string_validator.call("web_search(url: 'example.com')")).to be true
    end

    it "does not match partial tool names" do
      expect(validator.call("search_all(query: 'Ruby')")).to be false
    end
  end

  describe ".all_of" do
    subject(:validator) do
      described_class.all_of(
        described_class.contains("Ruby"),
        described_class.matches(/\d+/)
      )
    end

    it "returns true when all validators pass" do
      expect(validator.call("Ruby 4.0")).to be true
    end

    it "returns false when any validator fails" do
      expect(validator.call("Ruby is great")).to be false
      expect(validator.call("Version 4.0")).to be false
    end

    it "handles single validator" do
      single = described_class.all_of(described_class.contains("test"))
      expect(single.call("test")).to be true
    end

    it "handles empty validators" do
      empty = described_class.all_of
      expect(empty.call("anything")).to be true
    end
  end

  describe ".any_of" do
    subject(:validator) do
      described_class.any_of(
        described_class.contains("Ruby"),
        described_class.contains("Python")
      )
    end

    it "returns true when any validator passes" do
      expect(validator.call("Ruby is fast")).to be true
      expect(validator.call("Python is readable")).to be true
    end

    it "returns false when all validators fail" do
      expect(validator.call("Go is concurrent")).to be false
    end

    it "short-circuits on first match" do
      call_count = 0
      counting_validator = lambda do |_|
        call_count += 1
        true
      end
      never_called = lambda do |_|
        call_count += 1
        true
      end

      combined = described_class.any_of(counting_validator, never_called)
      combined.call("test")

      expect(call_count).to eq(1)
    end

    it "handles empty validators" do
      empty = described_class.any_of
      expect(empty.call("anything")).to be false
    end
  end

  describe ".none_of" do
    subject(:validator) do
      described_class.none_of(
        described_class.contains("error"),
        described_class.contains("fail")
      )
    end

    it "returns true when no validators pass" do
      expect(validator.call("Success!")).to be true
    end

    it "returns false when any validator passes" do
      expect(validator.call("This has an error")).to be false
      expect(validator.call("Task will fail")).to be false
    end

    it "handles empty validators" do
      empty = described_class.none_of
      expect(empty.call("anything")).to be true
    end
  end

  describe ".partial" do
    subject(:validator) do
      described_class.partial(
        described_class.contains("Ruby"),
        described_class.contains("Python"),
        described_class.contains("Go")
      )
    end

    it "returns fraction of passing validators" do
      expect(validator.call("Ruby and Go")).to be_within(0.001).of(2.0 / 3.0)
    end

    it "returns 1.0 when all pass" do
      expect(validator.call("Ruby Python Go")).to eq(1.0)
    end

    it "returns 0.0 when none pass" do
      expect(validator.call("Java")).to eq(0.0)
    end

    it "handles single validator" do
      single = described_class.partial(described_class.contains("test"))
      expect(single.call("test")).to eq(1.0)
      expect(single.call("nope")).to eq(0.0)
    end
  end

  describe "nested combinators" do
    it "supports deeply nested validators" do
      validator = described_class.all_of(
        described_class.any_of(
          described_class.contains("Ruby"),
          described_class.contains("Python")
        ),
        described_class.none_of(
          described_class.contains("error")
        )
      )

      expect(validator.call("Ruby is great")).to be true
      expect(validator.call("Ruby has an error")).to be false
      expect(validator.call("Go is fast")).to be false
    end

    it "supports partial within combinators" do
      partial_validator = described_class.partial(
        described_class.matches(/\d+/),
        described_class.matches(/\./),
        described_class.matches(/release/)
      )
      validator = described_class.all_of(
        described_class.contains("version"),
        ->(out) { partial_validator.call(out) >= 0.5 }
      )

      expect(validator.call("version 4.0")).to be true
      expect(validator.call("version info")).to be false
    end
  end

  describe "edge cases" do
    it "handles empty strings" do
      expect(described_class.contains("").call("anything")).to be true
      expect(described_class.equals("").call("  ")).to be true
    end

    it "handles unicode" do
      validator = described_class.contains("Ruby")
      expect(validator.call("Ruby is great")).to be true
    end

    it "handles multiline text" do
      validator = described_class.matches(/Ruby.*Python/m)
      expect(validator.call("Ruby\nand\nPython")).to be true
    end

    it "handles very long text" do
      long_text = "#{"x" * 10_000}needle#{"x" * 10_000}"
      validator = described_class.contains("needle")
      expect(validator.call(long_text)).to be true
    end
  end
end
