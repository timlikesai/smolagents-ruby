require "spec_helper"

RSpec.describe Smolagents::Http::UserAgent::Sanitizer do
  describe ".sanitize" do
    context "with nil or empty input" do
      it "returns nil for nil input" do
        expect(described_class.sanitize(nil, max_length: 64)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.sanitize("", max_length: 64)).to be_nil
      end

      it "returns nil for whitespace-only string that becomes empty after sanitization" do
        expect(described_class.sanitize("   ", max_length: 64)).to eq("___")
      end
    end

    context "with path components" do
      it "extracts base filename from path" do
        result = described_class.sanitize("org/models/llama-3", max_length: 64)

        expect(result).to eq("llama-3")
      end

      it "extracts filename from deep path" do
        result = described_class.sanitize("huggingface/meta/llama/llama-3.1-8b", max_length: 64)

        expect(result).to eq("llama-3.1-8b")
      end
    end

    context "with file extensions" do
      it "removes .gguf extension" do
        result = described_class.sanitize("model.gguf", max_length: 64)

        expect(result).to eq("model")
      end

      it "removes .bin extension" do
        result = described_class.sanitize("weights.bin", max_length: 64)

        expect(result).to eq("weights")
      end

      it "removes .pt extension" do
        result = described_class.sanitize("model.pt", max_length: 64)

        expect(result).to eq("model")
      end

      it "removes .safetensors extension" do
        result = described_class.sanitize("model.safetensors", max_length: 64)

        expect(result).to eq("model")
      end

      it "handles case-insensitive extensions" do
        result = described_class.sanitize("model.GGUF", max_length: 64)

        expect(result).to eq("model")
      end
    end

    context "with date stamps" do
      it "removes 8-digit date stamps" do
        result = described_class.sanitize("model-20240115", max_length: 64)

        expect(result).to eq("model")
      end

      it "removes longer date stamps" do
        result = described_class.sanitize("model-202401151234", max_length: 64)

        expect(result).to eq("model")
      end

      it "preserves non-date numeric suffixes" do
        result = described_class.sanitize("llama-3.1-8b", max_length: 64)

        expect(result).to eq("llama-3.1-8b")
      end
    end

    context "with invalid characters" do
      it "replaces spaces with underscores" do
        result = described_class.sanitize("my model name", max_length: 64)

        expect(result).to eq("my_model_name")
      end

      it "replaces special characters with underscores" do
        result = described_class.sanitize("model@v1#test", max_length: 64)

        expect(result).to eq("model_v1_test")
      end

      it "preserves valid characters" do
        result = described_class.sanitize("Model-Name_v1.0", max_length: 64)

        expect(result).to eq("Model-Name_v1.0")
      end
    end

    context "with length limits" do
      it "truncates to max_length" do
        long_name = "a" * 100
        result = described_class.sanitize(long_name, max_length: 64)

        expect(result.length).to eq(64)
      end

      it "respects custom max_length" do
        result = described_class.sanitize("long-model-name", max_length: 10)

        expect(result.length).to eq(10)
        expect(result).to eq("long-model")
      end
    end

    context "combined transformations" do
      it "applies all transformations in sequence" do
        result = described_class.sanitize(
          "huggingface/org/My Model@v2-20240115.gguf",
          max_length: 64
        )

        expect(result).to eq("My_Model_v2")
      end
    end
  end

  describe "EXTENSIONS" do
    it "contains expected file extensions" do
      expect(described_class::EXTENSIONS).to include("gguf", "bin", "pt", "safetensors")
    end

    it "is frozen" do
      expect(described_class::EXTENSIONS).to be_frozen
    end
  end

  describe "PATTERNS" do
    it "defines extension pattern" do
      expect(described_class::PATTERNS[:extension]).to be_a(Regexp)
    end

    it "defines date_stamp pattern" do
      expect(described_class::PATTERNS[:date_stamp]).to be_a(Regexp)
    end

    it "defines invalid_chars pattern" do
      expect(described_class::PATTERNS[:invalid_chars]).to be_a(Regexp)
    end

    it "is frozen" do
      expect(described_class::PATTERNS).to be_frozen
    end
  end
end
