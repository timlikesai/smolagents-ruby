require "spec_helper"

RSpec.describe Smolagents::Security::ArgumentValidator do
  describe ".validate" do
    context "with type validation" do
      describe "string type" do
        let(:rule) { Smolagents::Security::ValidationRule.for_string }

        it "passes for valid strings" do
          result = described_class.validate("hello world", rule)
          expect(result).to be_valid
          expect(result.sanitized_value).to eq("hello world")
        end

        it "fails for integers" do
          result = described_class.validate(42, rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("must be a string")
        end

        it "fails for arrays" do
          result = described_class.validate([], rule)
          expect(result).to be_invalid
        end

        it "fails for hashes" do
          result = described_class.validate({}, rule)
          expect(result).to be_invalid
        end
      end

      describe "integer type" do
        let(:rule) { Smolagents::Security::ValidationRule.for_integer }

        it "passes for valid integers" do
          result = described_class.validate(42, rule)
          expect(result).to be_valid
        end

        it "fails for strings" do
          result = described_class.validate("42", rule)
          expect(result).to be_invalid
        end

        it "fails for floats" do
          result = described_class.validate(3.14, rule)
          expect(result).to be_invalid
        end
      end

      describe "boolean type" do
        let(:rule) { Smolagents::Security::ValidationRule.for_boolean }

        it "passes for true" do
          result = described_class.validate(true, rule)
          expect(result).to be_valid
        end

        it "passes for false" do
          result = described_class.validate(false, rule)
          expect(result).to be_valid
        end

        it "fails for truthy values" do
          result = described_class.validate(1, rule)
          expect(result).to be_invalid
        end
      end

      describe "array type" do
        let(:rule) { Smolagents::Security::ValidationRule.for_array }

        it "passes for arrays" do
          result = described_class.validate([1, 2, 3], rule)
          expect(result).to be_valid
        end

        it "passes for empty arrays" do
          result = described_class.validate([], rule)
          expect(result).to be_valid
        end

        it "fails for strings" do
          result = described_class.validate("[]", rule)
          expect(result).to be_invalid
        end
      end

      describe "hash type" do
        let(:rule) { Smolagents::Security::ValidationRule.for_hash }

        it "passes for hashes" do
          result = described_class.validate({ key: "value" }, rule)
          expect(result).to be_valid
        end

        it "passes for empty hashes" do
          result = described_class.validate({}, rule)
          expect(result).to be_valid
        end
      end
    end

    context "with required validation" do
      it "fails when required value is nil" do
        rule = Smolagents::Security::ValidationRule.for_string(required: true)
        result = described_class.validate(nil, rule)
        expect(result).to be_invalid
        expect(result.errors).to include("is required")
      end

      it "passes when optional value is nil" do
        rule = Smolagents::Security::ValidationRule.for_string(required: false)
        result = described_class.validate(nil, rule)
        expect(result).to be_valid
        expect(result.sanitized_value).to be_nil
      end
    end

    context "with max_length validation" do
      describe "for strings" do
        it "passes for strings within limit" do
          rule = Smolagents::Security::ValidationRule.for_string(max_length: 10, detect_dangerous: false)
          result = described_class.validate("hello", rule)
          expect(result).to be_valid
        end

        it "passes for strings at limit" do
          rule = Smolagents::Security::ValidationRule.for_string(max_length: 10, detect_dangerous: false)
          result = described_class.validate("a" * 10, rule)
          expect(result).to be_valid
        end

        it "fails for strings over limit" do
          rule = Smolagents::Security::ValidationRule.for_string(max_length: 10, detect_dangerous: false)
          result = described_class.validate("a" * 11, rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("exceeds max length of 10")
        end
      end

      describe "for arrays" do
        it "passes for arrays within limit" do
          rule = Smolagents::Security::ValidationRule.for_array(max_length: 5)
          result = described_class.validate([1, 2, 3], rule)
          expect(result).to be_valid
        end

        it "fails for arrays over limit" do
          rule = Smolagents::Security::ValidationRule.for_array(max_length: 5)
          result = described_class.validate([1, 2, 3, 4, 5, 6], rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("exceeds max items of 5")
        end
      end
    end

    context "with pattern validation" do
      it "passes when pattern matches" do
        rule = Smolagents::Security::ValidationRule.for_string(pattern: /\A\w+\z/, detect_dangerous: false)
        result = described_class.validate("hello123", rule)
        expect(result).to be_valid
      end

      it "fails when pattern does not match" do
        rule = Smolagents::Security::ValidationRule.for_string(pattern: /\A\w+\z/, detect_dangerous: false)
        result = described_class.validate("hello world", rule)
        expect(result).to be_invalid
        expect(result.errors.first).to include("does not match required pattern")
      end
    end

    context "with dangerous content detection" do
      let(:rule) { Smolagents::Security::ValidationRule.for_string(detect_dangerous: true) }

      it "detects shell metacharacters" do
        result = described_class.validate("hello; world", rule)
        expect(result).to be_invalid
        expect(result.errors.first).to include("shell metacharacter")
      end

      it "detects SQL injection patterns" do
        result = described_class.validate("' OR 1=1--", rule)
        expect(result).to be_invalid
        expect(result.errors.first).to include("SQL injection")
      end

      it "detects path traversal" do
        result = described_class.validate("../etc/passwd", rule)
        expect(result).to be_invalid
        expect(result.errors.first).to include("path traversal")
      end

      it "allows safe text" do
        result = described_class.validate("hello world 123", rule)
        expect(result).to be_valid
      end
    end

    context "with sanitization" do
      it "removes dangerous characters when sanitize is true" do
        rule = Smolagents::Security::ValidationRule.for_string(sanitize: true, detect_dangerous: false)
        result = described_class.validate("hello; world", rule)
        expect(result).to be_valid
        expect(result.sanitized_value).to eq("hello world")
      end

      it "does not sanitize when sanitize is false" do
        rule = Smolagents::Security::ValidationRule.for_string(sanitize: false, detect_dangerous: false)
        result = described_class.validate("hello world", rule)
        expect(result.sanitized_value).to eq("hello world")
      end

      it "sanitizes even when there are no dangerous chars detected" do
        rule = Smolagents::Security::ValidationRule.for_string(sanitize: true, detect_dangerous: false)
        result = described_class.validate("test", rule)
        expect(result.sanitized_value).to eq("test")
      end
    end
  end

  describe ".validate_all" do
    let(:input_specs) do
      {
        query: { type: "string", description: "Search query" },
        limit: { type: "integer", description: "Result limit", nullable: true }
      }
    end

    it "validates all arguments" do
      results = described_class.validate_all({ query: "test", limit: 10 }, input_specs)
      expect(results[:query]).to be_valid
      expect(results[:limit]).to be_valid
    end

    it "returns hash of results keyed by argument name" do
      results = described_class.validate_all({ query: "test" }, input_specs)
      expect(results).to have_key(:query)
      expect(results).to have_key(:limit)
    end

    it "handles missing optional arguments" do
      results = described_class.validate_all({ query: "test" }, input_specs)
      expect(results[:query]).to be_valid
      expect(results[:limit]).to be_valid
      expect(results[:limit].sanitized_value).to be_nil
    end

    it "handles string keys in arguments" do
      results = described_class.validate_all({ "query" => "test" }, input_specs)
      expect(results[:query]).to be_valid
    end

    it "handles string keys in specs" do
      string_specs = {
        "query" => { type: "string", description: "Search query" }
      }
      results = described_class.validate_all({ query: "test" }, string_specs)
      expect(results[:query]).to be_valid
    end

    it "reports failures for invalid arguments" do
      results = described_class.validate_all({ query: 123 }, input_specs)
      expect(results[:query]).to be_invalid
    end

    it "validates multiple arguments" do
      multi_specs = {
        name: { type: "string", description: "Name" },
        age: { type: "integer", description: "Age" },
        active: { type: "boolean", description: "Active" }
      }
      results = described_class.validate_all(
        { name: "John", age: 30, active: true },
        multi_specs
      )
      expect(results[:name]).to be_valid
      expect(results[:age]).to be_valid
      expect(results[:active]).to be_valid
    end

    it "provides access to sanitized values in results" do
      specs = {
        text: { type: "string", sanitize: true, describe: "Text", detect_dangerous: false }
      }
      results = described_class.validate_all({ text: "hello world" }, specs)
      expect(results[:text].sanitized_value).to eq("hello world")
    end

    it "handles empty specifications" do
      results = described_class.validate_all({}, {})
      expect(results).to eq({})
    end
  end

  describe ".validate_all!" do
    let(:input_specs) do
      {
        query: { type: "string", description: "Search query", max_length: 100 }
      }
    end

    it "returns sanitized arguments on success" do
      result = described_class.validate_all!({ query: "test" }, input_specs, tool_name: "search")
      expect(result).to eq({ query: "test" })
    end

    it "raises ArgumentValidationError on failure" do
      expect do
        described_class.validate_all!({ query: 123 }, input_specs, tool_name: "search")
      end.to raise_error(Smolagents::Errors::ArgumentValidationError)
    end

    it "includes tool name in error" do
      expect do
        described_class.validate_all!({ query: 123 }, input_specs, tool_name: "search")
      end.to raise_error(Smolagents::Errors::ArgumentValidationError) do |error|
        expect(error.tool_name).to eq("search")
      end
    end

    it "includes failures in error" do
      expect do
        described_class.validate_all!({ query: 123 }, input_specs, tool_name: "search")
      end.to raise_error(Smolagents::Errors::ArgumentValidationError) do |error|
        expect(error.failures).to have_key(:query)
      end
    end

    it "raises on dangerous content" do
      expect do
        described_class.validate_all!({ query: "; rm -rf /" }, input_specs, tool_name: "search")
      end.to raise_error(Smolagents::Errors::ArgumentValidationError)
    end

    it "returns multiple sanitized arguments" do
      multi_specs = {
        name: { type: "string", description: "Name" },
        count: { type: "integer", description: "Count" }
      }
      result = described_class.validate_all!({ name: "test", count: 5 }, multi_specs, tool_name: "tool")
      expect(result[:name]).to eq("test")
      expect(result[:count]).to eq(5)
    end

    it "returns hash with sanitized values extracted" do
      specs = {
        text: { type: "string", sanitize: true, description: "Text", detect_dangerous: false }
      }
      result = described_class.validate_all!({ text: "hello world" }, specs, tool_name: "tool")
      expect(result[:text]).to eq("hello world")
    end

    it "stops at first validation failure for a single argument" do
      specs = {
        query: { type: "string", max_length: 5, pattern: /\A\w+\z/ }
      }
      # This will fail type first (it's an integer)
      expect do
        described_class.validate_all!({ query: 123 }, specs, tool_name: "tool")
      end.to raise_error(Smolagents::Errors::ArgumentValidationError)
    end
  end

  describe "integration scenarios" do
    it "validates search tool arguments" do
      specs = {
        query: { type: "string", description: "Search query", max_length: 500 },
        limit: { type: "integer", description: "Result count", nullable: true }
      }
      result = described_class.validate_all!(
        { query: "Ruby gems", limit: 10 },
        specs,
        tool_name: "search"
      )
      expect(result[:query]).to eq("Ruby gems")
      expect(result[:limit]).to eq(10)
    end

    it "rejects dangerous search queries" do
      specs = {
        query: { type: "string", description: "Search query" }
      }
      expect do
        described_class.validate_all!(
          { query: "; DROP TABLE users" },
          specs,
          tool_name: "search"
        )
      end.to raise_error(Smolagents::Errors::ArgumentValidationError)
    end

    it "handles input with shell chars when sanitization disabled" do
      specs = {
        command: { type: "string", description: "Command", detect_dangerous: false }
      }
      result = described_class.validate_all!(
        { command: "ls -la" },
        specs,
        tool_name: "executor"
      )
      expect(result[:command]).to eq("ls -la")
    end

    it "validates complex arguments" do
      specs = {
        email: { type: "string", pattern: /\A[\w.-]+@[\w.-]+\z/ },
        age: { type: "integer" },
        preferences: { type: "hash" }
      }
      result = described_class.validate_all!(
        { email: "user@example.com", age: 25, preferences: { theme: "dark" } },
        specs,
        tool_name: "user_tool"
      )
      expect(result[:email]).to eq("user@example.com")
      expect(result[:age]).to eq(25)
      expect(result[:preferences]).to eq({ theme: "dark" })
    end
  end
end
