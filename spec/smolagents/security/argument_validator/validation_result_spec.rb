require "spec_helper"

RSpec.describe Smolagents::Security::ArgumentValidationResult do
  describe ".success" do
    it "creates a valid result" do
      result = described_class.success(sanitized_value: "hello")
      expect(result.valid?).to be true
    end

    it "sets sanitized_value" do
      result = described_class.success(sanitized_value: "test")
      expect(result.sanitized_value).to eq("test")
    end

    it "sets valid to true" do
      result = described_class.success(sanitized_value: "data")
      expect(result.valid).to be true
    end

    it "has empty errors array" do
      result = described_class.success(sanitized_value: "value")
      expect(result.errors).to be_empty
    end

    it "errors are frozen" do
      result = described_class.success(sanitized_value: "value")
      expect(result.errors).to be_frozen
    end

    it "handles nil sanitized_value" do
      result = described_class.success(sanitized_value: nil)
      expect(result.sanitized_value).to be_nil
      expect(result.valid?).to be true
    end

    it "handles various data types" do
      result_str = described_class.success(sanitized_value: "string")
      result_int = described_class.success(sanitized_value: 42)
      result_arr = described_class.success(sanitized_value: [1, 2, 3])
      expect(result_str.sanitized_value).to eq("string")
      expect(result_int.sanitized_value).to eq(42)
      expect(result_arr.sanitized_value).to eq([1, 2, 3])
    end
  end

  describe ".failure" do
    it "creates an invalid result with error array" do
      result = described_class.failure(errors: ["error 1", "error 2"])
      expect(result.valid?).to be false
      expect(result.errors).to eq(["error 1", "error 2"])
    end

    it "sets valid to false" do
      result = described_class.failure(errors: ["error"])
      expect(result.valid).to be false
    end

    it "sets sanitized_value to nil" do
      result = described_class.failure(errors: ["error"])
      expect(result.sanitized_value).to be_nil
    end

    it "wraps single error in array" do
      result = described_class.failure(errors: "single error")
      expect(result.errors).to eq(["single error"])
    end

    it "accepts array of errors" do
      errors = ["error 1", "error 2", "error 3"]
      result = described_class.failure(errors:)
      expect(result.errors).to eq(errors)
    end

    it "freezes errors array" do
      result = described_class.failure(errors: ["error"])
      expect(result.errors).to be_frozen
    end

    it "invalid? returns true" do
      result = described_class.failure(errors: ["error"])
      expect(result.invalid?).to be true
    end

    it "invalid? returns false for valid result" do
      result = described_class.success(sanitized_value: "value")
      expect(result.invalid?).to be false
    end

    it "handles empty error array" do
      result = described_class.failure(errors: [])
      expect(result.valid?).to be false
      expect(result.errors).to be_empty
    end
  end

  describe "#valid?" do
    it "returns true for success results" do
      result = described_class.success(sanitized_value: "value")
      expect(result.valid?).to be true
    end

    it "returns false for failure results" do
      result = described_class.failure(errors: ["error"])
      expect(result.valid?).to be false
    end
  end

  describe "#invalid?" do
    it "returns false for success results" do
      result = described_class.success(sanitized_value: "value")
      expect(result.invalid?).to be false
    end

    it "returns true for failure results" do
      result = described_class.failure(errors: ["error"])
      expect(result.invalid?).to be true
    end
  end

  describe "immutability" do
    it "is immutable (Data.define)" do
      result = described_class.success(sanitized_value: "value")
      expect { result.valid = false }.to raise_error(NoMethodError)
    end

    it "prevents modification of errors array" do
      result = described_class.failure(errors: ["error"])
      expect { result.errors << "new error" }.to raise_error(FrozenError)
    end

    it "prevents modification of sanitized_value" do
      result = described_class.success(sanitized_value: "value")
      expect { result.sanitized_value = "new value" }.to raise_error(NoMethodError)
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "supports pattern matching for success" do
      result = described_class.success(sanitized_value: "hello")
      matched = case result
                in { valid: true, sanitized_value: "hello" }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "supports pattern matching for failure" do
      result = described_class.failure(errors: ["error"])
      matched = case result
                in { valid: false, errors: errors } if errors.any?
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "deconstruct_keys returns all fields" do
      result = described_class.success(sanitized_value: "test")
      keys = result.deconstruct_keys(nil)
      expect(keys).to have_key(:valid)
      expect(keys).to have_key(:errors)
      expect(keys).to have_key(:sanitized_value)
    end

    it "deconstruct_keys values are correct" do
      result = described_class.success(sanitized_value: "test")
      keys = result.deconstruct_keys(nil)
      expect(keys[:valid]).to be true
      expect(keys[:errors]).to be_empty
      expect(keys[:sanitized_value]).to eq("test")
    end
  end

  describe "integration scenarios" do
    it "represents successful validation with string" do
      result = described_class.success(sanitized_value: "hello world")
      expect(result.valid?).to be true
      expect(result.sanitized_value).to eq("hello world")
    end

    it "represents successful validation with integer" do
      result = described_class.success(sanitized_value: 42)
      expect(result.valid?).to be true
      expect(result.sanitized_value).to eq(42)
    end

    it "represents validation failure with type error" do
      result = described_class.failure(errors: ["must be a string"])
      expect(result.invalid?).to be true
      expect(result.errors).to include("must be a string")
    end

    it "represents validation failure with length error" do
      result = described_class.failure(errors: ["exceeds max length of 100"])
      expect(result.invalid?).to be true
      expect(result.errors).to include("exceeds max length of 100")
    end

    it "represents validation failure with pattern error" do
      result = described_class.failure(errors: ["does not match required pattern"])
      expect(result.invalid?).to be true
    end

    it "represents validation failure with multiple errors" do
      errors = [
        "must be a string",
        "exceeds max length of 50",
        "contains dangerous shell metacharacter: ;"
      ]
      result = described_class.failure(errors:)
      expect(result.invalid?).to be true
      expect(result.errors.size).to eq(3)
    end

    it "can be used in conditional logic" do
      result = described_class.success(sanitized_value: "data")
      raise "Unexpected failure" unless result.valid?

      sanitized = result.sanitized_value
      expect(sanitized).to eq("data")
    end

    it "can be destructured in pattern matching" do
      result = described_class.failure(errors: ["error 1", "error 2"])
      case result
      in { valid: false, errors:, sanitized_value: nil }
        expect(errors.size).to eq(2)
      else
        raise "Pattern match failed"
      end
    end
  end
end
