require "spec_helper"

RSpec.describe Smolagents::Concerns::Support::StringSanitization do
  subject(:sanitizer) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Support::StringSanitization
    end
  end

  describe "#sanitize_utf8" do
    context "with nil input" do
      it "returns empty string" do
        result = sanitizer.sanitize_utf8(nil)
        expect(result).to eq("")
      end

      it "returns valid empty string" do
        result = sanitizer.sanitize_utf8(nil)
        expect(result.valid_encoding?).to be true
      end
    end

    context "with valid UTF-8" do
      it "returns unchanged string" do
        input = "Hello, World!"
        result = sanitizer.sanitize_utf8(input)
        expect(result).to eq(input)
      end

      it "preserves UTF-8 characters" do
        input = "こんにちは世界" # Japanese
        result = sanitizer.sanitize_utf8(input)
        expect(result).to eq(input)
      end

      it "preserves emoji" do
        input = "Hello 👋 World 🌍"
        result = sanitizer.sanitize_utf8(input)
        expect(result).to eq(input)
      end

      it "preserves accented characters" do
        input = "Café naïve résumé"
        result = sanitizer.sanitize_utf8(input)
        expect(result).to eq(input)
      end

      it "preserves special symbols" do
        input = "© ® ™ € £ ¥"
        result = sanitizer.sanitize_utf8(input)
        expect(result).to eq(input)
      end
    end

    context "with invalid UTF-8" do
      it "replaces invalid bytes with replacement character" do
        invalid = "\xFF\xFE"
        result = sanitizer.sanitize_utf8(invalid)

        expect(result.valid_encoding?).to be true
        expect(result).to include("\uFFFD")
      end

      it "replaces all invalid bytes" do
        # Create a string with multiple invalid byte sequences
        invalid = "valid\xFFmore\xFEtext"
        result = sanitizer.sanitize_utf8(invalid)

        expect(result.valid_encoding?).to be true
        expect(result).to include("valid")
        expect(result).to include("more")
        expect(result).to include("text")
      end

      it "uses Unicode replacement character U+FFFD" do
        invalid = "test\xFFtest"
        result = sanitizer.sanitize_utf8(invalid)

        expect(result).to include("\uFFFD")
      end

      it "handles sequences of invalid bytes" do
        invalid = "\xFF\xFE\xFD"
        result = sanitizer.sanitize_utf8(invalid)

        expect(result.valid_encoding?).to be true
        expect(result.count("\uFFFD")).to be >= 1
      end
    end

    context "with mixed valid and invalid" do
      it "preserves valid parts and replaces invalid" do
        mixed = "Hello\xFFWorld"
        result = sanitizer.sanitize_utf8(mixed)

        expect(result).to start_with("Hello")
        expect(result).to end_with("World")
        expect(result.valid_encoding?).to be true
      end

      it "handles UTF-8 with embedded invalid bytes" do
        mixed = "valid\xC0\x80invalid"
        result = sanitizer.sanitize_utf8(mixed)

        expect(result.valid_encoding?).to be true
      end
    end

    context "with special UTF-8 cases" do
      it "handles overlong encodings" do
        # Overlong encoding for space
        overlong = "\xC0\x80"
        result = sanitizer.sanitize_utf8(overlong)

        expect(result.valid_encoding?).to be true
      end

      it "handles incomplete UTF-8 sequences at end" do
        incomplete = "test\xC0" # Incomplete UTF-8 sequence
        result = sanitizer.sanitize_utf8(incomplete)

        expect(result.valid_encoding?).to be true
      end

      it "handles BOM markers" do
        with_bom = "﻿content" # UTF-8 BOM
        result = sanitizer.sanitize_utf8(with_bom)

        expect(result.valid_encoding?).to be true
      end
    end

    context "with encoding flags" do
      it "returns string with UTF-8 encoding" do
        result = sanitizer.sanitize_utf8("test")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "converts from other encodings" do
        # Create a string in ASCII
        ascii_str = "Hello".force_encoding("ASCII-8BIT")
        result = sanitizer.sanitize_utf8(ascii_str)

        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "handles already UTF-8 strings" do
        utf8_str = "café".encode("UTF-8")
        result = sanitizer.sanitize_utf8(utf8_str)

        expect(result.encoding).to eq(Encoding::UTF_8)
      end
    end

    context "performance" do
      it "handles large strings" do
        large = "x" * 1_000_000
        result = sanitizer.sanitize_utf8(large)

        expect(result.length).to eq(large.length)
      end

      it "handles large strings with invalid bytes" do
        large = "#{"x" * 10_000}\xFF#{"y" * 10_000}" * 10
        result = sanitizer.sanitize_utf8(large)

        expect(result.valid_encoding?).to be true
      end
    end

    context "edge cases" do
      it "handles empty string" do
        result = sanitizer.sanitize_utf8("")
        expect(result).to eq("")
        expect(result.valid_encoding?).to be true
      end

      it "handles single character" do
        result = sanitizer.sanitize_utf8("a")
        expect(result).to eq("a")
      end

      it "handles single invalid byte" do
        result = sanitizer.sanitize_utf8("\xFF")
        expect(result.valid_encoding?).to be true
        expect(result).to include("\uFFFD")
      end

      it "handles only replacement characters" do
        # Create a string with replacement chars
        mixed = "\xAA\xBB\xCC"
        result = sanitizer.sanitize_utf8(mixed)

        expect(result.valid_encoding?).to be true
      end
    end

    context "integration" do
      it "is idempotent" do
        original = "test\xFFdata"
        sanitized1 = sanitizer.sanitize_utf8(original)
        sanitized2 = sanitizer.sanitize_utf8(sanitized1)

        expect(sanitized1).to eq(sanitized2)
      end

      it "handles real API response scenarios" do
        # Simulate malformed HTML response
        malformed = "<html>\xFF<body>Content</body>\xFE</html>"
        result = sanitizer.sanitize_utf8(malformed)

        expect(result.valid_encoding?).to be true
        expect(result).to include("<html>")
        expect(result).to include("<body>")
      end

      it "preserves JSON-like structures" do
        json_like = '{"key": "value\xFF"}'
        result = sanitizer.sanitize_utf8(json_like)

        expect(result.valid_encoding?).to be true
        expect(result).to include('{"key": "value')
      end
    end
  end

  describe "module inclusion" do
    it "can be included in classes" do
      klass = Class.new { include Smolagents::Concerns::Support::StringSanitization }
      instance = klass.new

      result = instance.sanitize_utf8("test")
      expect(result).to eq("test")
    end

    it "can be used as mixin" do
      module TestModule
        include Smolagents::Concerns::Support::StringSanitization
      end

      obj = Object.new
      obj.extend(TestModule)

      result = obj.sanitize_utf8("test")
      expect(result).to eq("test")
    end
  end
end
