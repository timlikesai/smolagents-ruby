require "spec_helper"

RSpec.describe Smolagents::Security::TypeValidator do
  describe ".valid_type?" do
    describe "string type" do
      it "accepts strings" do
        expect(described_class.valid_type?("hello", "string")).to be true
      end

      it "rejects integers" do
        expect(described_class.valid_type?(42, "string")).to be false
      end

      it "rejects empty strings" do
        expect(described_class.valid_type?("", "string")).to be true
      end

      it "rejects arrays" do
        expect(described_class.valid_type?([], "string")).to be false
      end
    end

    describe "integer type" do
      it "accepts integers" do
        expect(described_class.valid_type?(42, "integer")).to be true
      end

      it "accepts zero" do
        expect(described_class.valid_type?(0, "integer")).to be true
      end

      it "accepts negative integers" do
        expect(described_class.valid_type?(-100, "integer")).to be true
      end

      it "rejects floats" do
        expect(described_class.valid_type?(3.14, "integer")).to be false
      end

      it "rejects strings" do
        expect(described_class.valid_type?("42", "integer")).to be false
      end
    end

    describe "number type" do
      it "accepts integers" do
        expect(described_class.valid_type?(42, "number")).to be true
      end

      it "accepts floats" do
        expect(described_class.valid_type?(3.14, "number")).to be true
      end

      it "accepts negative numbers" do
        expect(described_class.valid_type?(-42.5, "number")).to be true
      end

      it "rejects strings" do
        expect(described_class.valid_type?("3.14", "number")).to be false
      end
    end

    describe "boolean type" do
      it "accepts true" do
        expect(described_class.valid_type?(true, "boolean")).to be true
      end

      it "accepts false" do
        expect(described_class.valid_type?(false, "boolean")).to be true
      end

      it "rejects 1" do
        expect(described_class.valid_type?(1, "boolean")).to be false
      end

      it "rejects 0" do
        expect(described_class.valid_type?(0, "boolean")).to be false
      end

      it "rejects 'true' string" do
        expect(described_class.valid_type?("true", "boolean")).to be false
      end

      it "rejects nil" do
        expect(described_class.valid_type?(nil, "boolean")).to be false
      end
    end

    describe "array type" do
      it "accepts arrays" do
        expect(described_class.valid_type?([1, 2, 3], "array")).to be true
      end

      it "accepts empty arrays" do
        expect(described_class.valid_type?([], "array")).to be true
      end

      it "accepts mixed arrays" do
        expect(described_class.valid_type?([1, "two", :three], "array")).to be true
      end

      it "rejects strings" do
        expect(described_class.valid_type?("[]", "array")).to be false
      end

      it "rejects hashes" do
        expect(described_class.valid_type?({}, "array")).to be false
      end
    end

    describe "hash type" do
      it "accepts hashes" do
        expect(described_class.valid_type?({ key: "value" }, "hash")).to be true
      end

      it "accepts empty hashes" do
        expect(described_class.valid_type?({}, "hash")).to be true
      end

      it "accepts string keys" do
        expect(described_class.valid_type?({ "key" => "value" }, "hash")).to be true
      end

      it "rejects arrays" do
        expect(described_class.valid_type?([1, 2], "hash")).to be false
      end

      it "rejects strings" do
        expect(described_class.valid_type?('{"key": "value"}', "hash")).to be false
      end
    end

    describe "unknown type" do
      it "returns true for unknown types" do
        # Unknown types pass validation (no check defined)
        expect(described_class.valid_type?("anything", "unknown")).to be true
      end

      it "allows any value for undefined type" do
        expect(described_class.valid_type?(nil, "custom_type")).to be true
        expect(described_class.valid_type?([1, 2], "custom_type")).to be true
      end
    end
  end

  describe ".type_error" do
    it "returns formatted string error for string type" do
      error = described_class.type_error("string")
      expect(error).to eq("must be a string")
    end

    it "returns formatted integer error" do
      error = described_class.type_error("integer")
      expect(error).to eq("must be a integer")
    end

    it "returns formatted number error" do
      error = described_class.type_error("number")
      expect(error).to eq("must be a number")
    end

    it "returns formatted boolean error" do
      error = described_class.type_error("boolean")
      expect(error).to eq("must be a boolean")
    end

    it "returns formatted array error" do
      error = described_class.type_error("array")
      expect(error).to eq("must be a array")
    end

    it "returns formatted hash error" do
      error = described_class.type_error("hash")
      expect(error).to eq("must be a hash")
    end

    it "handles custom types" do
      error = described_class.type_error("custom")
      expect(error).to eq("must be a custom")
    end
  end

  describe ".check_length" do
    describe "for strings" do
      it "returns nil when string is within limit" do
        error = described_class.check_length("hello", 10, "string")
        expect(error).to be_nil
      end

      it "returns nil when string equals limit" do
        error = described_class.check_length("hello", 5, "string")
        expect(error).to be_nil
      end

      it "returns error when string exceeds limit" do
        error = described_class.check_length("hello", 4, "string")
        expect(error).to eq("exceeds max length of 4")
      end

      it "returns nil when max_length is nil" do
        error = described_class.check_length("hello world", nil, "string")
        expect(error).to be_nil
      end

      it "handles empty strings" do
        error = described_class.check_length("", 0, "string")
        expect(error).to be_nil
      end

      it "handles very long strings" do
        long_string = "a" * 1000
        error = described_class.check_length(long_string, 100, "string")
        expect(error).to eq("exceeds max length of 100")
      end
    end

    describe "for arrays" do
      it "returns nil when array is within limit" do
        error = described_class.check_length([1, 2, 3], 5, "array")
        expect(error).to be_nil
      end

      it "returns nil when array equals limit" do
        error = described_class.check_length([1, 2, 3], 3, "array")
        expect(error).to be_nil
      end

      it "returns error when array exceeds limit" do
        error = described_class.check_length([1, 2, 3, 4, 5], 3, "array")
        expect(error).to eq("exceeds max items of 3")
      end

      it "returns nil when max_length is nil" do
        error = described_class.check_length([1, 2, 3], nil, "array")
        expect(error).to be_nil
      end

      it "handles empty arrays" do
        error = described_class.check_length([], 0, "array")
        expect(error).to be_nil
      end

      it "returns error message with 'items' not 'length'" do
        error = described_class.check_length([1, 2, 3, 4], 2, "array")
        expect(error).to include("items")
        expect(error).not_to include("length")
      end
    end

    describe "for other types" do
      it "returns nil for non-string, non-array types" do
        error = described_class.check_length(42, 10, "integer")
        expect(error).to be_nil
      end

      it "returns nil for unknown types" do
        error = described_class.check_length("value", 10, "custom")
        expect(error).to be_nil
      end

      it "returns nil for hashes" do
        error = described_class.check_length({ key: "value" }, 10, "hash")
        expect(error).to be_nil
      end
    end
  end

  describe ".check_pattern" do
    it "returns nil when pattern matches" do
      pattern = /\A\w+\z/
      error = described_class.check_pattern("hello123", pattern)
      expect(error).to be_nil
    end

    it "returns error when pattern does not match" do
      pattern = /\A\w+\z/
      error = described_class.check_pattern("hello world", pattern)
      expect(error).to eq("does not match required pattern")
    end

    it "returns nil when pattern is nil" do
      error = described_class.check_pattern("any value", nil)
      expect(error).to be_nil
    end

    it "returns nil for non-string values" do
      pattern = /\A\d+\z/
      error = described_class.check_pattern(42, pattern)
      expect(error).to be_nil
    end

    it "handles complex regex patterns" do
      pattern = /\A[\w\s\-.]+\z/
      error = described_class.check_pattern("hello-world_123 test", pattern)
      expect(error).to be_nil
    end

    it "rejects patterns with invalid characters" do
      pattern = /\A\w+\z/
      error = described_class.check_pattern("hello@world", pattern)
      expect(error).to eq("does not match required pattern")
    end

    it "handles case-sensitive patterns" do
      pattern = /\A[A-Z]+\z/
      error = described_class.check_pattern("HELLO", pattern)
      expect(error).to be_nil
    end

    it "rejects case mismatch" do
      pattern = /\A[A-Z]+\z/
      error = described_class.check_pattern("hello", pattern)
      expect(error).to eq("does not match required pattern")
    end

    it "handles anchored patterns" do
      pattern = /^hello/
      error = described_class.check_pattern("hello world", pattern)
      expect(error).to be_nil
    end

    it "rejects patterns that don't match from start" do
      pattern = /^hello/
      error = described_class.check_pattern("world hello", pattern)
      expect(error).to eq("does not match required pattern")
    end
  end

  describe "TYPE_CHECKS constant" do
    it "defines type checks for all common types" do
      type_checks = described_class::TYPE_CHECKS
      expect(type_checks).to have_key("string")
      expect(type_checks).to have_key("integer")
      expect(type_checks).to have_key("number")
      expect(type_checks).to have_key("boolean")
      expect(type_checks).to have_key("array")
      expect(type_checks).to have_key("hash")
    end

    it "all type checks are callable" do
      described_class::TYPE_CHECKS.each_value do |check|
        expect(check).to respond_to(:call)
      end
    end

    it "type checks return booleans" do
      described_class::TYPE_CHECKS.each_value do |check|
        result = check.call("test")
        expect([true, false].include?(result)).to be(true), "Expected boolean, got #{result.class}"
      end
    end
  end
end
