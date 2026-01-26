require "spec_helper"

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

    it "accepts max_length parameter" do
      rule = described_class.for_string(max_length: 100)
      expect(rule.max_length).to eq(100)
    end

    it "accepts pattern parameter" do
      pattern = /\A\w+\z/
      rule = described_class.for_string(pattern:)
      expect(rule.pattern).to eq(pattern)
    end

    it "accepts required parameter" do
      rule = described_class.for_string(required: true)
      expect(rule.required).to be true
    end

    it "accepts sanitize parameter" do
      rule = described_class.for_string(sanitize: true)
      expect(rule.sanitize).to be true
    end

    it "accepts detect_dangerous parameter" do
      rule = described_class.for_string(detect_dangerous: false)
      expect(rule.detect_dangerous).to be false
    end

    it "combines all parameters" do
      pattern = /\A[\w\s]+\z/
      rule = described_class.for_string(
        max_length: 500, pattern:, required: true,
        sanitize: true, detect_dangerous: false
      )
      expect(rule.type).to eq("string")
      expect(rule.max_length).to eq(500)
      expect(rule.pattern).to eq(pattern)
      expect(rule.required).to be true
      expect(rule.sanitize).to be true
      expect(rule.detect_dangerous).to be false
    end

    it "enables danger detection by default for strings" do
      rule = described_class.for_string
      expect(rule.detect_dangerous).to be true
    end
  end

  describe ".for_integer" do
    it "creates an integer rule" do
      rule = described_class.for_integer
      expect(rule.type).to eq("integer")
      expect(rule.max_length).to be_nil
      expect(rule.pattern).to be_nil
      expect(rule.required).to be false
      expect(rule.sanitize).to be false
      expect(rule.detect_dangerous).to be false
    end

    it "accepts required parameter" do
      rule = described_class.for_integer(required: true)
      expect(rule.required).to be true
    end

    it "disables danger detection for integers" do
      rule = described_class.for_integer
      expect(rule.detect_dangerous).to be false
    end
  end

  describe ".for_boolean" do
    it "creates a boolean rule" do
      rule = described_class.for_boolean
      expect(rule.type).to eq("boolean")
      expect(rule.max_length).to be_nil
      expect(rule.pattern).to be_nil
      expect(rule.required).to be false
      expect(rule.sanitize).to be false
      expect(rule.detect_dangerous).to be false
    end

    it "accepts required parameter" do
      rule = described_class.for_boolean(required: true)
      expect(rule.required).to be true
    end
  end

  describe ".for_array" do
    it "creates an array rule" do
      rule = described_class.for_array
      expect(rule.type).to eq("array")
      expect(rule.max_length).to be_nil
      expect(rule.pattern).to be_nil
      expect(rule.required).to be false
      expect(rule.sanitize).to be false
      expect(rule.detect_dangerous).to be false
    end

    it "accepts max_length parameter" do
      rule = described_class.for_array(max_length: 10)
      expect(rule.max_length).to eq(10)
    end

    it "accepts required parameter" do
      rule = described_class.for_array(required: true)
      expect(rule.required).to be true
    end

    it "disables danger detection for arrays" do
      rule = described_class.for_array
      expect(rule.detect_dangerous).to be false
    end
  end

  describe ".for_hash" do
    it "creates a hash rule" do
      rule = described_class.for_hash
      expect(rule.type).to eq("hash")
      expect(rule.max_length).to be_nil
      expect(rule.pattern).to be_nil
      expect(rule.required).to be false
      expect(rule.sanitize).to be false
      expect(rule.detect_dangerous).to be false
    end

    it "accepts required parameter" do
      rule = described_class.for_hash(required: true)
      expect(rule.required).to be true
    end
  end

  describe ".from_spec" do
    it "creates rule from tool input spec" do
      spec = { type: "string", description: "Query" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
      expect(rule.detect_dangerous).to be true
    end

    it "extracts max_length from spec" do
      spec = { type: "string", description: "Query", max_length: 500 }
      rule = described_class.from_spec(spec)
      expect(rule.max_length).to eq(500)
    end

    it "extracts pattern from spec" do
      pattern = /\A\w+\z/
      spec = { type: "string", description: "Query", pattern: }
      rule = described_class.from_spec(spec)
      expect(rule.pattern).to eq(pattern)
    end

    it "treats nullable: true as required: false" do
      spec = { type: "string", description: "Query", nullable: true }
      rule = described_class.from_spec(spec)
      expect(rule.required).to be false
    end

    it "treats missing nullable as required: true" do
      spec = { type: "string", description: "Query" }
      rule = described_class.from_spec(spec)
      expect(rule.required).to be true
    end

    it "extracts sanitize from spec" do
      spec = { type: "string", description: "Query", sanitize: true }
      rule = described_class.from_spec(spec)
      expect(rule.sanitize).to be true
    end

    it "respects detect_dangerous override" do
      spec = { type: "string", description: "Query", detect_dangerous: false }
      rule = described_class.from_spec(spec)
      expect(rule.detect_dangerous).to be false
    end

    it "enables detect_dangerous by default for strings" do
      spec = { type: "string", description: "Query" }
      rule = described_class.from_spec(spec)
      expect(rule.detect_dangerous).to be true
    end

    it "disables detect_dangerous for non-string types" do
      spec = { type: "integer", description: "Count" }
      rule = described_class.from_spec(spec)
      expect(rule.detect_dangerous).to be false
    end

    it "handles array types by taking first" do
      spec = { type: %w[string integer], description: "Mixed" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
    end

    it "handles string keys in spec" do
      spec = { "type" => "string", "description" => "Query" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
    end

    it "handles symbol keys in spec" do
      spec = { type: "string", description: "Query" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
    end

    it "merges all parameters correctly" do
      spec = {
        type: "string",
        description: "Query",
        max_length: 200,
        pattern: /\A\w+\z/,
        nullable: false,
        sanitize: true,
        detect_dangerous: false
      }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
      expect(rule.max_length).to eq(200)
      expect(rule.pattern).to eq(/\A\w+\z/)
      expect(rule.required).to be true
      expect(rule.sanitize).to be true
      expect(rule.detect_dangerous).to be false
    end

    it "handles minimal spec" do
      spec = { type: "string" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
      expect(rule.max_length).to be_nil
      expect(rule.pattern).to be_nil
    end

    it "handles integer type from spec" do
      spec = { type: "integer", description: "Count" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("integer")
      expect(rule.detect_dangerous).to be false
    end

    it "handles boolean type from spec" do
      spec = { type: "boolean", description: "Flag" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("boolean")
      expect(rule.detect_dangerous).to be false
    end

    it "handles array type from spec" do
      spec = { type: "array", description: "Items", max_length: 10 }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("array")
      expect(rule.max_length).to eq(10)
    end

    it "handles hash type from spec" do
      spec = { type: "hash", description: "Data" }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("hash")
    end
  end

  describe "immutability" do
    it "is immutable (Data.define)" do
      rule = described_class.for_string
      expect { rule.type = "integer" }.to raise_error(NoMethodError)
    end

    it "prevents field modification" do
      rule = described_class.for_string(max_length: 100)
      expect { rule.max_length = 200 }.to raise_error(NoMethodError)
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "supports pattern matching" do
      rule = described_class.for_string(max_length: 100, required: true)
      matched = case rule
                in { type: "string", max_length: 100, required: true }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "deconstruct_keys returns all fields" do
      rule = described_class.for_string(max_length: 100)
      keys = rule.deconstruct_keys(nil)
      expect(keys).to have_key(:type)
      expect(keys).to have_key(:max_length)
      expect(keys).to have_key(:pattern)
      expect(keys).to have_key(:required)
      expect(keys).to have_key(:sanitize)
      expect(keys).to have_key(:detect_dangerous)
    end
  end

  describe "integration scenarios" do
    it "models a required string with pattern" do
      rule = described_class.for_string(
        max_length: 100,
        pattern: /\A[\w\s\-.]+\z/,
        required: true,
        detect_dangerous: true
      )
      expect(rule.required).to be true
      expect(rule.pattern).to be_a(Regexp)
      expect(rule.detect_dangerous).to be true
    end

    it "models an optional sanitized string" do
      rule = described_class.for_string(
        sanitize: true,
        detect_dangerous: false,
        required: false
      )
      expect(rule.required).to be false
      expect(rule.sanitize).to be true
    end

    it "models a bounded array" do
      rule = described_class.for_array(max_length: 50, required: true)
      expect(rule.type).to eq("array")
      expect(rule.max_length).to eq(50)
      expect(rule.required).to be true
    end

    it "can be created from JSON tool spec" do
      spec = {
        "type" => "string",
        "description" => "User query",
        "max_length" => 200,
        "nullable" => false,
        "detect_dangerous" => true
      }
      rule = described_class.from_spec(spec)
      expect(rule.type).to eq("string")
      expect(rule.required).to be true
      expect(rule.max_length).to eq(200)
    end
  end
end
