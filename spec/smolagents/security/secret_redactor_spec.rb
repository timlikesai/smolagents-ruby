require "spec_helper"

RSpec.describe Smolagents::Security::SecretRedactor do
  describe "REDACTED constant" do
    it "is set to [REDACTED]" do
      expect(described_class::REDACTED).to eq("[REDACTED]")
    end

    it "is frozen" do
      expect(described_class::REDACTED).to be_frozen
    end
  end

  describe ".redact_string" do
    context "with OpenAI API keys" do
      it "redacts standard OpenAI API keys (sk-...)" do
        str = "Using key sk-abc123def456ghi789jkl012mno345pqr"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
        expect(result).not_to include("sk-abc123")
      end

      it "redacts OpenAI keys at start of string" do
        str = "sk-abc123def456ghi789jkl012mno345pqr is my key"
        result = described_class.redact_string(str)

        expect(result).to start_with("[REDACTED]")
      end

      it "redacts multiple OpenAI keys" do
        str = "Key1: sk-aaa111bbb222ccc333ddd444eee Key2: sk-fff555ggg666hhh777iii888jjj"
        result = described_class.redact_string(str)

        expect(result.scan("[REDACTED]").length).to be >= 2
        expect(result).not_to include("sk-aaa")
        expect(result).not_to include("sk-fff")
      end
    end

    context "with OpenAI project keys" do
      it "redacts project keys (sk-proj-...)" do
        str = "Project key is sk-proj-abc123def456ghi789jkl012mno345pqr"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
        expect(result).not_to include("sk-proj-")
      end

      it "redacts project keys with dashes and underscores" do
        str = "Using sk-proj-abc_123-def_456-ghi_789-jkl"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with Anthropic API keys" do
      it "redacts older Anthropic keys (sk-ant-...)" do
        str = "Anthropic key: sk-ant-abc123def456ghi789jkl012mno345pqr"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
        expect(result).not_to include("sk-ant-")
      end
    end

    context "with 64-character hex tokens" do
      it "redacts 64-char lowercase hex tokens" do
        token = "a" * 64
        str = "Token: #{token}"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
        expect(result).not_to include(token)
      end

      it "redacts mixed hex tokens" do
        token = "#{"abc123" * 11}ab" # 68 chars but first 64 will match
        str = "Token: #{token[0, 64]}"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with Bearer tokens" do
      it "redacts Bearer tokens in headers" do
        str = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
        expect(result).not_to include("eyJhbGci")
      end

      it "redacts case-insensitive Bearer tokens" do
        str = "authorization: bearer mySecretToken123456789"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts Bearer with JWT tokens" do
        jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature123"
        str = "Bearer #{jwt}"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with api_key patterns" do
      it "redacts api_key in config syntax" do
        str = 'config = { api_key: "abcd1234567890efgh" }'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts api-key with hyphen" do
        str = 'api-key: "abcd1234567890efgh12"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts apikey without separator" do
        str = 'apikey="abcd1234567890efgh12"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts API_KEY in environment format" do
        str = 'API_KEY="secretkey1234567890abc"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with token patterns" do
      it "redacts token assignments" do
        str = 'token = "myverysecrettoken12345678"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts token in JSON format" do
        str = '{"token": "abcdef123456789012345678"}'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with secret patterns" do
      it "redacts secret assignments" do
        str = 'secret="thisisaverylongsecret1234"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts client_secret patterns" do
        str = 'client_secret: "verylongsecretvalue12345"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with password patterns" do
      it "redacts password assignments" do
        str = 'password="mysecretpassword"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts PASSWORD in environment format" do
        str = 'DATABASE_PASSWORD="complexpass123"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end

      it "redacts passwords with special characters" do
        str = 'password="P@ssw0rd!#$%"'
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
      end
    end

    context "with safe strings" do
      it "preserves normal text" do
        str = "Hello, this is a normal message without secrets"
        result = described_class.redact_string(str)

        expect(result).to eq(str)
      end

      it "preserves short strings that look like keys" do
        str = "sk-short"
        result = described_class.redact_string(str)

        expect(result).to eq(str)
      end

      it "preserves URLs without tokens" do
        str = "https://api.example.com/v1/endpoint"
        result = described_class.redact_string(str)

        expect(result).to eq(str)
      end

      it "preserves code without secrets" do
        str = 'user = User.find(1)\nname = user.name'
        result = described_class.redact_string(str)

        expect(result).to eq(str)
      end
    end

    context "edge cases" do
      it "handles empty string" do
        expect(described_class.redact_string("")).to eq("")
      end

      it "handles string with only whitespace" do
        expect(described_class.redact_string("   ")).to eq("   ")
      end

      it "handles unicode strings without secrets" do
        str = "Hello, world!"
        result = described_class.redact_string(str)

        expect(result).to eq(str)
      end

      it "redacts secrets embedded in long text" do
        str = "The configuration includes api_key: \"verylongsecretapikey1234\" for authentication"
        result = described_class.redact_string(str)

        expect(result).to include("[REDACTED]")
        expect(result).to include("configuration")
        expect(result).to include("authentication")
      end
    end
  end

  describe ".redact_hash" do
    context "with sensitive keys" do
      it "redacts values for api_key" do
        hash = { api_key: "secret123", name: "test" }
        result = described_class.redact_hash(hash)

        expect(result["api_key"]).to eq("[REDACTED]")
        expect(result["name"]).to eq("test")
      end

      it "redacts values for apiKey (camelCase)" do
        hash = { "apiKey" => "secret123" }
        result = described_class.redact_hash(hash)

        expect(result["apiKey"]).to eq("[REDACTED]")
      end

      it "redacts values for token" do
        hash = { token: "abc123xyz" }
        result = described_class.redact_hash(hash)

        expect(result["token"]).to eq("[REDACTED]")
      end

      it "redacts values for secret" do
        hash = { secret: "hidden_value" }
        result = described_class.redact_hash(hash)

        expect(result["secret"]).to eq("[REDACTED]")
      end

      it "redacts values for password" do
        hash = { password: "P@ssw0rd!" }
        result = described_class.redact_hash(hash)

        expect(result["password"]).to eq("[REDACTED]")
      end

      it "redacts values for auth" do
        hash = { auth: "auth_token_value" }
        result = described_class.redact_hash(hash)

        expect(result["auth"]).to eq("[REDACTED]")
      end

      it "redacts values for credential" do
        hash = { credential: "cred_value" }
        result = described_class.redact_hash(hash)

        expect(result["credential"]).to eq("[REDACTED]")
      end

      it "redacts values for key" do
        hash = { key: "key_value" }
        result = described_class.redact_hash(hash)

        expect(result["key"]).to eq("[REDACTED]")
      end
    end

    context "with compound sensitive keys" do
      it "redacts auth_token" do
        hash = { auth_token: "abc" }
        result = described_class.redact_hash(hash)

        expect(result["auth_token"]).to eq("[REDACTED]")
      end

      it "redacts ACCESS_TOKEN (uppercase)" do
        hash = { "ACCESS_TOKEN" => "token123" }
        result = described_class.redact_hash(hash)

        expect(result["ACCESS_TOKEN"]).to eq("[REDACTED]")
      end

      it "redacts database_password" do
        hash = { database_password: "dbpass" }
        result = described_class.redact_hash(hash)

        expect(result["database_password"]).to eq("[REDACTED]")
      end

      it "redacts client_secret" do
        hash = { client_secret: "secret" }
        result = described_class.redact_hash(hash)

        expect(result["client_secret"]).to eq("[REDACTED]")
      end
    end

    context "with nested structures" do
      it "redacts nested sensitive values" do
        hash = { config: { token: "abc123", url: "https://example.com" } }
        result = described_class.redact_hash(hash)

        expect(result["config"]["token"]).to eq("[REDACTED]")
        expect(result["config"]["url"]).to eq("https://example.com")
      end

      it "redacts deeply nested values" do
        hash = {
          level1: {
            level2: {
              api_key: "deep_secret"
            }
          }
        }
        result = described_class.redact_hash(hash)

        expect(result["level1"]["level2"]["api_key"]).to eq("[REDACTED]")
      end

      it "handles arrays within hashes" do
        hash = {
          users: [
            { name: "Alice", api_key: "key1" },
            { name: "Bob", api_key: "key2" }
          ]
        }
        result = described_class.redact_hash(hash)

        expect(result["users"][0]["api_key"]).to eq("[REDACTED]")
        expect(result["users"][1]["api_key"]).to eq("[REDACTED]")
        expect(result["users"][0]["name"]).to eq("Alice")
      end
    end

    context "with symbol and string keys" do
      it "converts symbol keys to strings" do
        hash = { api_key: "secret" }
        result = described_class.redact_hash(hash)

        expect(result).to have_key("api_key")
        expect(result).not_to have_key(:api_key)
      end

      it "preserves string keys" do
        hash = { "api_key" => "secret" }
        result = described_class.redact_hash(hash)

        expect(result).to have_key("api_key")
      end

      it "handles mixed key types" do
        hash = { api_key: "s1", "token" => "s2", password: "s3" }
        result = described_class.redact_hash(hash)

        expect(result.values.uniq).to eq(["[REDACTED]"])
      end
    end

    context "with non-sensitive keys" do
      it "preserves safe string values" do
        hash = { name: "Test", url: "https://example.com" }
        result = described_class.redact_hash(hash)

        expect(result["name"]).to eq("Test")
        expect(result["url"]).to eq("https://example.com")
      end

      it "preserves numeric values" do
        hash = { count: 42, api_key: "secret" }
        result = described_class.redact_hash(hash)

        expect(result["count"]).to eq(42)
        expect(result["api_key"]).to eq("[REDACTED]")
      end

      it "preserves boolean values" do
        hash = { enabled: true, api_key: "secret" }
        result = described_class.redact_hash(hash)

        expect(result["enabled"]).to be true
      end

      it "preserves nil values" do
        hash = { value: nil, api_key: "secret" }
        result = described_class.redact_hash(hash)

        expect(result["value"]).to be_nil
      end
    end

    context "edge cases" do
      it "handles empty hash" do
        expect(described_class.redact_hash({})).to eq({})
      end

      it "handles hash with all sensitive keys" do
        hash = { api_key: "s1", token: "s2", password: "s3" }
        result = described_class.redact_hash(hash)

        expect(result.values.uniq).to eq(["[REDACTED]"])
      end

      it "handles hash with no sensitive keys" do
        hash = { name: "test", count: 5 }
        result = described_class.redact_hash(hash)

        expect(result).to eq({ "name" => "test", "count" => 5 })
      end
    end
  end

  describe ".redact" do
    context "with strings" do
      it "redacts secret patterns in strings" do
        result = described_class.redact("sk-abc123def456ghi789jkl012mno345pqr")
        expect(result).to eq("[REDACTED]")
      end

      it "preserves normal strings" do
        result = described_class.redact("Hello world")
        expect(result).to eq("Hello world")
      end

      it "redacts entire string when it looks like a secret" do
        secret = "sk-verylongsecretkey12345678901234567890"
        result = described_class.redact(secret)

        expect(result).to eq("[REDACTED]")
      end
    end

    context "with hashes" do
      it "delegates to redact_hash" do
        result = described_class.redact({ api_key: "secret" })
        expect(result["api_key"]).to eq("[REDACTED]")
      end
    end

    context "with arrays" do
      it "redacts each element" do
        result = described_class.redact(["normal", { api_key: "secret" }])

        expect(result[0]).to eq("normal")
        expect(result[1]["api_key"]).to eq("[REDACTED]")
      end

      it "handles nested arrays" do
        result = described_class.redact([["inner", { token: "abc" }]])

        expect(result[0][0]).to eq("inner")
        expect(result[0][1]["token"]).to eq("[REDACTED]")
      end

      it "handles arrays of secrets" do
        secrets = %w[sk-abc123def456ghi789jkl012mno345pqr normal]
        result = described_class.redact(secrets)

        expect(result[0]).to eq("[REDACTED]")
        expect(result[1]).to eq("normal")
      end
    end

    context "with other types" do
      it "returns integers unchanged" do
        expect(described_class.redact(123)).to eq(123)
      end

      it "returns floats unchanged" do
        expect(described_class.redact(3.14)).to eq(3.14)
      end

      it "returns nil unchanged" do
        expect(described_class.redact(nil)).to be_nil
      end

      it "returns true unchanged" do
        expect(described_class.redact(true)).to be true
      end

      it "returns false unchanged" do
        expect(described_class.redact(false)).to be false
      end

      it "returns symbols unchanged" do
        expect(described_class.redact(:symbol)).to eq(:symbol)
      end
    end

    context "with complex nested structures" do
      it "handles deeply nested mixed structures" do
        data = {
          config: {
            api: {
              key: "sk-abc123def456ghi789jkl012mno345pqr",
              url: "https://api.example.com"
            },
            users: [
              { name: "Alice", token: "secret1" },
              { name: "Bob", token: "secret2" }
            ]
          },
          metadata: {
            version: "1.0",
            credentials: { password: "hunter2" }
          }
        }

        result = described_class.redact(data)

        expect(result["config"]["api"]["key"]).to eq("[REDACTED]")
        expect(result["config"]["api"]["url"]).to eq("https://api.example.com")
        expect(result["config"]["users"][0]["token"]).to eq("[REDACTED]")
        expect(result["config"]["users"][1]["token"]).to eq("[REDACTED]")
        # "credentials" key contains "credential" so entire value is redacted
        expect(result["metadata"]["credentials"]).to eq("[REDACTED]")
        expect(result["metadata"]["version"]).to eq("1.0")
      end

      it "recursively redacts when parent key is not sensitive" do
        data = {
          settings: {
            database: {
              password: "secret123"
            }
          }
        }

        result = described_class.redact(data)

        # settings and database are not sensitive keys, so recursion happens
        expect(result["settings"]["database"]["password"]).to eq("[REDACTED]")
      end
    end
  end

  describe ".safe_inspect" do
    it "returns inspected string with secrets redacted" do
      value = { result: "success", api_key: "sk-verysecretkey12345678901234567890" }
      result = described_class.safe_inspect(value)

      expect(result).to include("success")
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("sk-verysecret")
    end

    it "handles nested structures" do
      value = { outer: { inner: { token: "secret" } } }
      result = described_class.safe_inspect(value)

      expect(result).to include("[REDACTED]")
      expect(result).to include("outer")
      expect(result).to include("inner")
    end

    it "handles arrays" do
      value = [{ api_key: "secret" }, "normal"]
      result = described_class.safe_inspect(value)

      expect(result).to include("[REDACTED]")
      expect(result).to include("normal")
    end

    it "handles simple strings" do
      result = described_class.safe_inspect("Hello")
      expect(result).to eq('"Hello"')
    end

    it "handles strings containing secrets" do
      result = described_class.safe_inspect("Bearer eyJtoken123456789")
      expect(result).to include("[REDACTED]")
    end
  end

  describe ".looks_like_secret?" do
    context "with OpenAI keys" do
      it "returns true for standard OpenAI keys" do
        expect(described_class.looks_like_secret?("sk-abc123def456ghi789jkl012mno345pqr")).to be true
      end

      it "returns true for project keys" do
        expect(described_class.looks_like_secret?("sk-proj-abc123def456ghi789jkl012mno")).to be true
      end
    end

    context "with Anthropic keys" do
      it "returns true for Anthropic keys" do
        expect(described_class.looks_like_secret?("sk-ant-abc123def456ghi789jkl012mno345")).to be true
      end
    end

    context "with Bearer tokens" do
      it "returns true for Bearer tokens" do
        expect(described_class.looks_like_secret?("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")).to be true
      end
    end

    context "with short strings" do
      it "returns false for strings under 16 characters" do
        expect(described_class.looks_like_secret?("short")).to be false
      end

      it "returns false for exactly 15 characters" do
        expect(described_class.looks_like_secret?("a" * 15)).to be false
      end
    end

    context "with normal long strings" do
      it "returns false for sentences" do
        expect(described_class.looks_like_secret?("This is a normal long sentence")).to be false
      end

      it "returns false for URLs" do
        expect(described_class.looks_like_secret?("https://example.com/path")).to be false
      end
    end

    context "with non-string types" do
      it "returns false for integers" do
        expect(described_class.looks_like_secret?(12_345_678_901_234_567_890)).to be false
      end

      it "returns false for arrays" do
        expect(described_class.looks_like_secret?(["secret"])).to be false
      end

      it "returns false for hashes" do
        expect(described_class.looks_like_secret?({ key: "value" })).to be false
      end

      it "returns false for nil" do
        expect(described_class.looks_like_secret?(nil)).to be false
      end

      it "returns false for symbols" do
        expect(described_class.looks_like_secret?(:secret_key_value_long)).to be false
      end
    end
  end

  describe ".sensitive_key?" do
    context "with sensitive key names" do
      it "returns true for api_key" do
        expect(described_class.sensitive_key?("api_key")).to be true
      end

      it "returns true for apiKey" do
        expect(described_class.sensitive_key?("apiKey")).to be true
      end

      it "returns true for token" do
        expect(described_class.sensitive_key?("token")).to be true
      end

      it "returns true for secret" do
        expect(described_class.sensitive_key?("secret")).to be true
      end

      it "returns true for password" do
        expect(described_class.sensitive_key?("password")).to be true
      end

      it "returns true for auth" do
        expect(described_class.sensitive_key?("auth")).to be true
      end

      it "returns true for credential" do
        expect(described_class.sensitive_key?("credential")).to be true
      end

      it "returns true for key" do
        expect(described_class.sensitive_key?("key")).to be true
      end
    end

    context "with compound sensitive keys" do
      it "returns true for auth_token" do
        expect(described_class.sensitive_key?("auth_token")).to be true
      end

      it "returns true for access_token" do
        expect(described_class.sensitive_key?("access_token")).to be true
      end

      it "returns true for client_secret" do
        expect(described_class.sensitive_key?("client_secret")).to be true
      end

      it "returns true for database_password" do
        expect(described_class.sensitive_key?("database_password")).to be true
      end
    end

    context "with case variations" do
      it "returns true for API_KEY (uppercase)" do
        expect(described_class.sensitive_key?("API_KEY")).to be true
      end

      it "returns true for ApiKey (mixed case)" do
        expect(described_class.sensitive_key?("ApiKey")).to be true
      end

      it "returns true for PASSWORD (uppercase)" do
        expect(described_class.sensitive_key?("PASSWORD")).to be true
      end
    end

    context "with symbol keys" do
      it "returns true for symbol :api_key" do
        expect(described_class.sensitive_key?(:api_key)).to be true
      end

      it "returns true for symbol :token" do
        expect(described_class.sensitive_key?(:token)).to be true
      end
    end

    context "with non-sensitive keys" do
      it "returns false for name" do
        expect(described_class.sensitive_key?("name")).to be false
      end

      it "returns false for url" do
        expect(described_class.sensitive_key?("url")).to be false
      end

      it "returns false for count" do
        expect(described_class.sensitive_key?("count")).to be false
      end

      it "returns false for data" do
        expect(described_class.sensitive_key?("data")).to be false
      end
    end

    context "with nil" do
      it "returns false for nil" do
        expect(described_class.sensitive_key?(nil)).to be false
      end
    end
  end

  describe "SECRET_PATTERNS constant" do
    let(:patterns) { described_class::SECRET_PATTERNS }

    it "is an array" do
      expect(patterns).to be_an(Array)
    end

    it "is frozen" do
      expect(patterns).to be_frozen
    end

    it "contains regex patterns" do
      expect(patterns.all?(Regexp)).to be true
    end

    it "includes OpenAI key pattern" do
      expect(patterns.any? { |p| "sk-abc123def456ghi789jkl" =~ p }).to be true
    end

    it "includes project key pattern" do
      expect(patterns.any? { |p| "sk-proj-abc123def456ghi789jkl" =~ p }).to be true
    end

    it "includes Anthropic key pattern" do
      expect(patterns.any? { |p| "sk-ant-abc123def456ghi789jkl" =~ p }).to be true
    end

    it "includes Bearer token pattern" do
      expect(patterns.any? { |p| "Bearer mytoken123456" =~ p }).to be true
    end
  end

  describe "to_s and inspect safety" do
    it "does not leak secrets through standard Ruby inspection" do
      data = { api_key: "sk-supersecretkey1234567890abcdefghij" }
      safe = described_class.safe_inspect(data)

      expect(safe).not_to include("sk-supersecret")
    end

    it "can be used in error messages safely" do
      data = { token: "Bearer secretJWT123456789" }
      safe = described_class.safe_inspect(data)

      expect(safe).to include("[REDACTED]")
      expect(safe).not_to include("secretJWT")
    end
  end

  describe "thread safety" do
    it "handles concurrent redaction calls" do
      # Minimal thread count to verify thread safety without excessive overhead
      results = Array.new(3) do
        Thread.new do
          [
            described_class.redact({ api_key: "secret123" }),
            described_class.redact_string("Bearer tokensuffix")
          ]
        end
      end.map(&:value)

      expect(results.size).to eq(3)
      expect(results).to all(be_an(Array))
    end
  end

  describe "idempotency" do
    it "produces same result when applied multiple times" do
      original = { api_key: "sk-secret1234567890abcdefghij" }
      first_pass = described_class.redact(original)
      second_pass = described_class.redact(first_pass)

      expect(first_pass).to eq(second_pass)
    end

    it "already redacted values remain redacted" do
      redacted = { api_key: "[REDACTED]" }
      result = described_class.redact(redacted)

      expect(result["api_key"]).to eq("[REDACTED]")
    end
  end
end
