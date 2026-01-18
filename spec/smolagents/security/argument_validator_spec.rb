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
          expect(result.errors.first).to include("must be a string")
        end

        it "fails for hashes" do
          result = described_class.validate({}, rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("must be a string")
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
          expect(result.errors.first).to include("must be a integer")
        end

        it "fails for floats" do
          result = described_class.validate(3.14, rule)
          expect(result).to be_invalid
        end
      end

      describe "number type" do
        let(:rule) do
          Smolagents::Security::ValidationRule.new(
            type: "number", max_length: nil, pattern: nil,
            required: false, sanitize: false, detect_dangerous: false
          )
        end

        it "passes for integers" do
          result = described_class.validate(42, rule)
          expect(result).to be_valid
        end

        it "passes for floats" do
          result = described_class.validate(3.14, rule)
          expect(result).to be_valid
        end

        it "fails for strings" do
          result = described_class.validate("3.14", rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("must be a number")
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
          expect(result.errors.first).to include("must be a boolean")
        end

        it "fails for strings" do
          result = described_class.validate("true", rule)
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
          expect(result.errors.first).to include("must be a array")
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

        it "fails for arrays" do
          result = described_class.validate([], rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("must be a hash")
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
        let(:rule) { Smolagents::Security::ValidationRule.for_string(max_length: 10, detect_dangerous: false) }

        it "passes for strings within limit" do
          result = described_class.validate("hello", rule)
          expect(result).to be_valid
        end

        it "passes for strings at limit" do
          result = described_class.validate("a" * 10, rule)
          expect(result).to be_valid
        end

        it "fails for strings over limit" do
          result = described_class.validate("a" * 11, rule)
          expect(result).to be_invalid
          expect(result.errors.first).to include("exceeds max length of 10")
        end
      end

      describe "for arrays" do
        let(:rule) { Smolagents::Security::ValidationRule.for_array(max_length: 5) }

        it "passes for arrays within limit" do
          result = described_class.validate([1, 2, 3], rule)
          expect(result).to be_valid
        end

        it "fails for arrays over limit" do
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

      it "works with alphanumeric pattern" do
        rule = Smolagents::Security::ValidationRule.for_string(pattern: /\A[\w\s\-.]+\z/, detect_dangerous: false)
        result = described_class.validate("hello-world_123", rule)
        expect(result).to be_valid
      end
    end

    context "with dangerous content detection" do
      describe "shell metacharacters" do
        let(:rule) { Smolagents::Security::ValidationRule.for_string(detect_dangerous: true) }

        it "detects semicolon (command chaining)" do
          result = described_class.validate("hello; rm -rf /", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains dangerous shell metacharacter: ;")
        end

        it "detects pipe (command piping)" do
          result = described_class.validate("cat file | less", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains dangerous shell metacharacter: |")
        end

        it "detects ampersand (background execution)" do
          result = described_class.validate("sleep 100 &", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains dangerous shell metacharacter: &")
        end

        it "detects dollar sign (variable expansion)" do
          result = described_class.validate("echo $PATH", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains dangerous shell metacharacter: $")
        end

        it "detects backtick (command substitution)" do
          result = described_class.validate("echo `whoami`", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains dangerous shell metacharacter: `")
        end

        it "detects redirect operators" do
          %w[< >].each do |char|
            result = described_class.validate("file #{char} output", rule)
            expect(result).to be_invalid
            expect(result.errors).to include("contains dangerous shell metacharacter: #{char}")
          end
        end

        it "allows safe text" do
          result = described_class.validate("hello world 123", rule)
          expect(result).to be_valid
        end

        it "limits errors to 3" do
          result = described_class.validate("; | & $ ` \\ < > ( )", rule)
          expect(result.errors.length).to be <= 3
        end
      end

      describe "SQL injection patterns" do
        let(:rule) { Smolagents::Security::ValidationRule.for_string(detect_dangerous: true) }

        it "detects OR 1=1 injection" do
          result = described_class.validate("' OR 1=1--", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains potential SQL injection pattern")
        end

        it "detects UNION SELECT injection" do
          result = described_class.validate("1 UNION SELECT * FROM users", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains potential SQL injection pattern")
        end

        it "detects DROP TABLE injection" do
          result = described_class.validate("; DROP TABLE users", rule)
          expect(result).to be_invalid
        end

        it "detects comment injection" do
          result = described_class.validate("admin'--", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains potential SQL injection pattern")
        end

        it "detects OR with string comparison" do
          result = described_class.validate("' OR 'x'='x", rule)
          expect(result).to be_invalid
        end
      end

      describe "path traversal patterns" do
        let(:rule) { Smolagents::Security::ValidationRule.for_string(detect_dangerous: true) }

        it "detects ../ unix style" do
          result = described_class.validate("../etc/passwd", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains path traversal attempt")
        end

        it "detects ..\\ windows style" do
          result = described_class.validate("..\\windows\\system32", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains path traversal attempt")
        end

        it "detects URL-encoded traversal" do
          result = described_class.validate("%2e%2e/etc/passwd", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains path traversal attempt")
        end

        it "detects double-encoded traversal" do
          result = described_class.validate("%252e%252e", rule)
          expect(result).to be_invalid
          expect(result.errors).to include("contains path traversal attempt")
        end

        it "allows normal paths" do
          rule_safe = Smolagents::Security::ValidationRule.for_string(detect_dangerous: false)
          result = described_class.validate("/home/user/documents", rule_safe)
          expect(result).to be_valid
        end
      end
    end

    context "with sanitization" do
      it "removes dangerous characters when sanitize is true" do
        rule = Smolagents::Security::ValidationRule.for_string(sanitize: true, detect_dangerous: false)
        result = described_class.validate("hello; world", rule)
        expect(result).to be_valid
        expect(result.sanitized_value).to eq("hello world")
      end

      it "applies sanitization to value when sanitize is true" do
        # Create a rule with large max_length but that still sanitizes
        rule = Smolagents::Security::ValidationRule.for_string(max_length: 100, sanitize: true, detect_dangerous: false)
        # The semicolon will be removed by sanitization
        result = described_class.validate("hello;world", rule)
        expect(result).to be_valid
        expect(result.sanitized_value).to eq("helloworld")
      end

      it "does not sanitize when sanitize is false" do
        rule = Smolagents::Security::ValidationRule.for_string(sanitize: false, detect_dangerous: false)
        result = described_class.validate("hello world", rule)
        expect(result.sanitized_value).to eq("hello world")
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

    it "handles missing optional arguments" do
      results = described_class.validate_all({ query: "test" }, input_specs)
      expect(results[:query]).to be_valid
      expect(results[:limit]).to be_valid
      expect(results[:limit].sanitized_value).to be_nil
    end

    it "handles string keys" do
      results = described_class.validate_all({ "query" => "test" }, input_specs)
      expect(results[:query]).to be_valid
    end

    it "reports failures for invalid arguments" do
      results = described_class.validate_all({ query: 123 }, input_specs)
      expect(results[:query]).to be_invalid
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
        expect(error.failures[:query].first).to include("must be a string")
      end
    end

    it "raises on dangerous content" do
      expect do
        described_class.validate_all!({ query: "; rm -rf /" }, input_specs, tool_name: "search")
      end.to raise_error(Smolagents::Errors::ArgumentValidationError)
    end
  end
end

RSpec.describe Smolagents::Security::ValidationRule do
  describe ".for_string" do
    it "creates a string rule with defaults" do
      rule = described_class.for_string
      expect(rule.type).to eq("string")
      expect(rule.max_length).to be_nil
      expect(rule.pattern).to be_nil
      expect(rule.required).to be false
      expect(rule.sanitize).to be false
      expect(rule.detect_dangerous).to be true
    end

    it "accepts custom options" do
      rule = described_class.for_string(
        max_length: 100, pattern: /\A\w+\z/, required: true,
        sanitize: true, detect_dangerous: false
      )
      expect(rule.max_length).to eq(100)
      expect(rule.pattern).to eq(/\A\w+\z/)
      expect(rule.required).to be true
      expect(rule.sanitize).to be true
      expect(rule.detect_dangerous).to be false
    end
  end

  describe ".for_integer" do
    it "creates an integer rule" do
      rule = described_class.for_integer
      expect(rule.type).to eq("integer")
      expect(rule.detect_dangerous).to be false
    end

    it "accepts required option" do
      rule = described_class.for_integer(required: true)
      expect(rule.required).to be true
    end
  end

  describe ".for_boolean" do
    it "creates a boolean rule" do
      rule = described_class.for_boolean
      expect(rule.type).to eq("boolean")
      expect(rule.detect_dangerous).to be false
    end
  end

  describe ".for_array" do
    it "creates an array rule with max_length" do
      rule = described_class.for_array(max_length: 10)
      expect(rule.type).to eq("array")
      expect(rule.max_length).to eq(10)
    end
  end

  describe ".for_hash" do
    it "creates a hash rule" do
      rule = described_class.for_hash
      expect(rule.type).to eq("hash")
    end
  end

  describe ".from_spec" do
    it "creates rule from tool input spec" do
      spec = { type: "string", description: "Query", max_length: 500, pattern: /\A\w+\z/ }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
      expect(rule.max_length).to eq(500)
      expect(rule.pattern).to eq(/\A\w+\z/)
      expect(rule.required).to be true # not nullable
      expect(rule.detect_dangerous).to be true
    end

    it "handles nullable spec" do
      spec = { type: "string", description: "Query", nullable: true }
      rule = described_class.from_spec(spec)
      expect(rule.required).to be false
    end

    it "handles sanitize option" do
      spec = { type: "string", description: "Query", sanitize: true }
      rule = described_class.from_spec(spec)
      expect(rule.sanitize).to be true
    end

    it "respects detect_dangerous override" do
      spec = { type: "string", description: "Query", detect_dangerous: false }
      rule = described_class.from_spec(spec)
      expect(rule.detect_dangerous).to be false
    end

    it "disables detect_dangerous for non-string types" do
      spec = { type: "integer", description: "Count" }
      rule = described_class.from_spec(spec)
      expect(rule.detect_dangerous).to be false
    end

    it "handles array types" do
      spec = { type: %w[string integer], description: "Mixed" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string") # Takes first
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      rule = described_class.for_string(max_length: 100)

      matched = case rule
                in { type: "string", max_length: 100 }
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end
end

RSpec.describe Smolagents::Security::ArgumentValidationResult do
  describe ".success" do
    it "creates a valid result" do
      result = described_class.success(sanitized_value: "hello")
      expect(result.valid?).to be true
      expect(result.invalid?).to be false
      expect(result.errors).to be_empty
      expect(result.sanitized_value).to eq("hello")
    end
  end

  describe ".failure" do
    it "creates an invalid result" do
      result = described_class.failure(errors: ["error 1", "error 2"])
      expect(result.valid?).to be false
      expect(result.invalid?).to be true
      expect(result.errors).to eq(["error 1", "error 2"])
      expect(result.sanitized_value).to be_nil
    end

    it "freezes errors array" do
      result = described_class.failure(errors: ["error"])
      expect(result.errors).to be_frozen
    end

    it "wraps single error in array" do
      result = described_class.failure(errors: "single error")
      expect(result.errors).to eq(["single error"])
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      result = described_class.success(sanitized_value: "test")

      matched = case result
                in { valid: true, sanitized_value: "test" }
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end
end

RSpec.describe Smolagents::Tools::Tool do
  let(:tool_class) do
    Class.new(described_class) do
      self.tool_name = "test_tool"
      self.description = "A test tool"
      self.inputs = {
        query: { type: "string", description: "Search query", max_length: 100 },
        count: { type: "integer", description: "Result count", nullable: true }
      }
      self.output_type = "string"

      def execute(query:, count: 10)
        "Searched for '#{query}' with limit #{count}"
      end
    end
  end

  let(:tool) { tool_class.new }

  describe "#validate_and_sanitize_arguments" do
    it "validates and returns arguments" do
      result = tool.validate_and_sanitize_arguments(query: "hello", count: 5)
      expect(result[:query]).to eq("hello")
      expect(result[:count]).to eq(5)
    end

    it "raises on invalid type" do
      expect do
        tool.validate_and_sanitize_arguments(query: 123)
      end.to raise_error(Smolagents::ArgumentValidationError)
    end

    it "raises on dangerous content" do
      expect do
        tool.validate_and_sanitize_arguments(query: "; rm -rf /")
      end.to raise_error(Smolagents::ArgumentValidationError)
    end

    it "handles string keys" do
      result = tool.validate_and_sanitize_arguments("query" => "hello")
      expect(result[:query]).to eq("hello")
    end
  end

  describe "#call with security validation" do
    it "validates arguments before execution" do
      expect do
        tool.call(query: "; DROP TABLE users")
      end.to raise_error(Smolagents::ArgumentValidationError)
    end

    it "executes with valid arguments" do
      result = tool.call(query: "hello world")
      expect(result.data).to include("hello world")
    end
  end

  describe "with custom pattern validation" do
    let(:strict_tool_class) do
      Class.new(described_class) do
        self.tool_name = "strict_tool"
        self.description = "A strict tool"
        self.inputs = {
          query: {
            type: "string",
            description: "Search query",
            max_length: 100,
            pattern: /\A[\w\s\-.]+\z/
          }
        }
        self.output_type = "string"

        def execute(query:)
          "Searched for '#{query}'"
        end
      end
    end

    let(:strict_tool) { strict_tool_class.new }

    it "allows matching patterns" do
      result = strict_tool.call(query: "hello-world_123")
      expect(result.data).to include("hello-world_123")
    end

    it "rejects non-matching patterns" do
      expect do
        strict_tool.call(query: "hello@world")
      end.to raise_error(Smolagents::ArgumentValidationError)
    end
  end

  describe "with security_validation_enabled? override" do
    let(:unsafe_tool_class) do
      Class.new(described_class) do
        self.tool_name = "unsafe_tool"
        self.description = "A tool without security validation"
        self.inputs = {
          query: { type: "string", description: "Search query" }
        }
        self.output_type = "string"

        def security_validation_enabled? = false

        def execute(query:)
          "Searched for '#{query}'"
        end
      end
    end

    let(:unsafe_tool) { unsafe_tool_class.new }

    it "skips validation when disabled" do
      result = unsafe_tool.call(query: "; rm -rf /")
      expect(result.data).to include("; rm -rf /")
    end
  end
end
