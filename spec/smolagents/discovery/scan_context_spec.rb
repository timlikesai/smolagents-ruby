require "smolagents"

RSpec.describe Smolagents::Discovery::ScanContext do
  describe "initialization" do
    it "creates context with all required fields" do
      ctx = described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      expect(ctx.provider).to eq(:lm_studio)
      expect(ctx.host).to eq("localhost")
      expect(ctx.port).to eq(1234)
      expect(ctx.timeout).to eq(2.0)
      expect(ctx.tls).to be false
      expect(ctx.api_key).to be_nil
    end

    it "accepts TLS and API key configuration" do
      ctx = described_class.new(
        provider: :openai_compatible,
        host: "api.example.com",
        port: 443,
        timeout: 5.0,
        tls: true,
        api_key: "sk-test-key"
      )

      expect(ctx.tls).to be true
      expect(ctx.api_key).to eq("sk-test-key")
    end
  end

  describe "#base_url" do
    it "builds HTTP URL when tls is false" do
      ctx = described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      expect(ctx.base_url).to eq("http://localhost:1234")
    end

    it "builds HTTPS URL when tls is true" do
      ctx = described_class.new(
        provider: :openai_compatible,
        host: "api.example.com",
        port: 443,
        timeout: 2.0,
        tls: true,
        api_key: nil
      )

      expect(ctx.base_url).to eq("https://api.example.com:443")
    end

    it "handles non-standard ports" do
      ctx = described_class.new(
        provider: :vllm,
        host: "192.168.1.100",
        port: 8000,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      expect(ctx.base_url).to eq("http://192.168.1.100:8000")
    end
  end

  describe "#with_defaults" do
    let(:ctx) do
      described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )
    end

    it "creates new context with specified tls" do
      new_ctx = ctx.with_defaults(tls: true)

      expect(new_ctx.tls).to be true
      expect(new_ctx.api_key).to be_nil
    end

    it "creates new context with specified api_key" do
      new_ctx = ctx.with_defaults(api_key: "new-key")

      expect(new_ctx.api_key).to eq("new-key")
      expect(new_ctx.tls).to be false
    end

    it "creates new context with both tls and api_key" do
      new_ctx = ctx.with_defaults(tls: true, api_key: "secure-key")

      expect(new_ctx.tls).to be true
      expect(new_ctx.api_key).to eq("secure-key")
    end

    it "preserves all other fields" do
      new_ctx = ctx.with_defaults(tls: true, api_key: "key")

      expect(new_ctx.provider).to eq(:lm_studio)
      expect(new_ctx.host).to eq("localhost")
      expect(new_ctx.port).to eq(1234)
      expect(new_ctx.timeout).to eq(2.0)
    end

    it "returns a new instance" do
      new_ctx = ctx.with_defaults(tls: true)

      expect(new_ctx).not_to be(ctx)
    end

    it "does not modify original context" do
      ctx.with_defaults(tls: true, api_key: "new")

      expect(ctx.tls).to be false
      expect(ctx.api_key).to be_nil
    end
  end

  describe "immutability" do
    let(:ctx) do
      described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )
    end

    it "does not allow modification of provider" do
      expect { ctx.provider = :ollama }.to raise_error(NoMethodError)
    end

    it "does not allow modification of host" do
      expect { ctx.host = "other" }.to raise_error(NoMethodError)
    end

    it "is a Data class" do
      expect(described_class.ancestors).to include(Data)
    end
  end

  describe "equality" do
    it "considers contexts with same values equal" do
      ctx1 = described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      ctx2 = described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      expect(ctx1).to eq(ctx2)
    end

    it "considers contexts with different values not equal" do
      ctx1 = described_class.new(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      ctx2 = described_class.new(
        provider: :ollama,
        host: "localhost",
        port: 11_434,
        timeout: 2.0,
        tls: false,
        api_key: nil
      )

      expect(ctx1).not_to eq(ctx2)
    end
  end
end
