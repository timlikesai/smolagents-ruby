RSpec.describe Smolagents::SecretRedactor do
  describe ".redact_string" do
    it "redacts OpenAI API keys" do
      str = "Using key sk-abc123def456ghi789jkl012mno345pqr"
      expect(described_class.redact_string(str)).to include("[REDACTED]")
      expect(described_class.redact_string(str)).not_to include("sk-abc123")
    end

    it "redacts OpenAI project keys" do
      str = "Key is sk-proj-abc123def456ghi789jkl012mno345pqr"
      expect(described_class.redact_string(str)).to include("[REDACTED]")
    end

    it "redacts Bearer tokens" do
      str = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
      expect(described_class.redact_string(str)).to include("[REDACTED]")
    end

    it "redacts api_key patterns" do
      str = 'config = { api_key: "abcd1234567890efgh" }'
      expect(described_class.redact_string(str)).to include("[REDACTED]")
    end

    it "preserves normal strings" do
      str = "Hello, this is a normal message"
      expect(described_class.redact_string(str)).to eq(str)
    end
  end

  describe ".redact_hash" do
    it "redacts values with sensitive keys" do
      hash = { api_key: "secret123", name: "test" }
      result = described_class.redact_hash(hash)

      expect(result["api_key"]).to eq("[REDACTED]")
      expect(result["name"]).to eq("test")
    end

    it "redacts nested sensitive values" do
      hash = { config: { token: "abc123", url: "https://example.com" } }
      result = described_class.redact_hash(hash)

      expect(result["config"]["token"]).to eq("[REDACTED]")
      expect(result["config"]["url"]).to eq("https://example.com")
    end

    it "handles various key formats" do
      hash = {
        "apiKey" => "secret1",
        :api_key => "secret2",
        "secret" => "secret3",
        "password" => "secret4",
        "AUTH_TOKEN" => "secret5"
      }
      result = described_class.redact_hash(hash)

      expect(result.values.uniq).to eq(["[REDACTED]"])
    end
  end

  describe ".redact" do
    it "handles strings" do
      expect(described_class.redact("sk-abc123def456ghi789jkl012mno345pqr")).to eq("[REDACTED]")
    end

    it "handles hashes" do
      result = described_class.redact({ key: "value", api_key: "secret" })
      expect(result["api_key"]).to eq("[REDACTED]")
    end

    it "handles arrays" do
      result = described_class.redact(["normal", { api_key: "secret" }])
      expect(result[0]).to eq("normal")
      expect(result[1]["api_key"]).to eq("[REDACTED]")
    end

    it "handles other types" do
      expect(described_class.redact(123)).to eq(123)
      expect(described_class.redact(nil)).to be_nil
      expect(described_class.redact(true)).to be true
    end
  end

  describe ".safe_inspect" do
    it "redacts API keys in inspected output" do
      value = { result: "success", api_key: "sk-verysecretkey123456789012345" }
      result = described_class.safe_inspect(value)

      expect(result).to include("success")
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("sk-verysecret")
    end
  end

  describe ".looks_like_secret?" do
    it "returns true for OpenAI keys" do
      expect(described_class.looks_like_secret?("sk-abc123def456ghi789jkl012mno345pqr")).to be true
    end

    it "returns false for short strings" do
      expect(described_class.looks_like_secret?("short")).to be false
    end

    it "returns false for normal long strings" do
      expect(described_class.looks_like_secret?("this is a normal long string")).to be false
    end

    it "returns false for non-strings" do
      expect(described_class.looks_like_secret?(12_345)).to be false
    end
  end
end
