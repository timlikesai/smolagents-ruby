require "smolagents"

RSpec.describe Smolagents::Discovery::UrlParser do
  describe ".parse_endpoints_env" do
    around do |example|
      original = ENV.fetch("SMOLAGENTS_SERVERS", nil)
      example.run
    ensure
      if original
        ENV["SMOLAGENTS_SERVERS"] = original
      else
        ENV.delete("SMOLAGENTS_SERVERS")
      end
    end

    it "returns empty array when env var not set" do
      ENV.delete("SMOLAGENTS_SERVERS")

      expect(described_class.parse_endpoints_env).to eq([])
    end

    it "returns empty array when env var is empty" do
      ENV["SMOLAGENTS_SERVERS"] = ""

      expect(described_class.parse_endpoints_env).to eq([])
    end

    it "parses single server URL" do
      ENV["SMOLAGENTS_SERVERS"] = "http://localhost:1234"

      endpoints = described_class.parse_endpoints_env

      expect(endpoints.length).to eq(1)
      expect(endpoints.first[:host]).to eq("localhost")
      expect(endpoints.first[:port]).to eq(1234)
    end

    it "parses multiple servers separated by semicolon" do
      ENV["SMOLAGENTS_SERVERS"] = "http://localhost:1234;http://server2:8080"

      endpoints = described_class.parse_endpoints_env

      expect(endpoints.length).to eq(2)
      expect(endpoints.first[:host]).to eq("localhost")
      expect(endpoints.last[:host]).to eq("server2")
    end

    it "strips whitespace from entries" do
      ENV["SMOLAGENTS_SERVERS"] = "http://localhost:1234 ; http://server2:8080 "

      endpoints = described_class.parse_endpoints_env

      expect(endpoints.length).to eq(2)
    end

    it "skips invalid URLs" do
      ENV["SMOLAGENTS_SERVERS"] = "http://valid:1234;not-a-url;http://also-valid:8080"

      endpoints = described_class.parse_endpoints_env

      expect(endpoints.length).to eq(2)
    end
  end

  describe ".parse_server_url" do
    it "parses HTTP URL" do
      endpoint = described_class.parse_server_url("http://localhost:1234")

      expect(endpoint[:host]).to eq("localhost")
      expect(endpoint[:port]).to eq(1234)
      expect(endpoint[:tls]).to be false
      expect(endpoint[:api_key]).to be_nil
    end

    it "parses HTTPS URL" do
      endpoint = described_class.parse_server_url("https://api.example.com:443")

      expect(endpoint[:host]).to eq("api.example.com")
      expect(endpoint[:port]).to eq(443)
      expect(endpoint[:tls]).to be true
    end

    it "defaults HTTP port to 80" do
      endpoint = described_class.parse_server_url("http://localhost")

      expect(endpoint[:port]).to eq(80)
    end

    it "defaults HTTPS port to 443" do
      endpoint = described_class.parse_server_url("https://example.com")

      expect(endpoint[:port]).to eq(443)
    end

    it "parses API key after pipe separator" do
      endpoint = described_class.parse_server_url("http://localhost:8080|sk-test-key")

      expect(endpoint[:host]).to eq("localhost")
      expect(endpoint[:port]).to eq(8080)
      expect(endpoint[:api_key]).to eq("sk-test-key")
    end

    it "strips whitespace from API key" do
      endpoint = described_class.parse_server_url("http://localhost:8080| sk-key ")

      expect(endpoint[:api_key]).to eq("sk-key")
    end

    it "sets api_key to nil for empty key after pipe" do
      endpoint = described_class.parse_server_url("http://localhost:8080|")

      expect(endpoint[:api_key]).to be_nil
    end

    it "returns nil for invalid URL" do
      endpoint = described_class.parse_server_url("not a url")

      expect(endpoint).to be_nil
    end

    it "returns endpoint with empty host for URL without host" do
      # URI parsing accepts empty host, returns empty string
      endpoint = described_class.parse_server_url("http://:8080/path")

      expect(endpoint[:host]).to eq("")
    end
  end

  describe ".infer_provider" do
    it "infers lm_studio from port 1234" do
      uri = URI("http://localhost:1234")

      expect(described_class.infer_provider(uri)).to eq(:lm_studio)
    end

    it "infers ollama from port 11434" do
      uri = URI("http://localhost:11434")

      expect(described_class.infer_provider(uri)).to eq(:ollama)
    end

    it "infers vllm from port 8000" do
      uri = URI("http://localhost:8000")

      expect(described_class.infer_provider(uri)).to eq(:vllm)
    end

    it "infers lm_studio from hostname containing lmstudio" do
      uri = URI("http://lmstudio.local:8080")

      expect(described_class.infer_provider(uri)).to eq(:lm_studio)
    end

    it "infers lm_studio from hostname containing lm-studio" do
      uri = URI("http://lm-studio-server:8080")

      expect(described_class.infer_provider(uri)).to eq(:lm_studio)
    end

    it "infers ollama from hostname containing ollama" do
      uri = URI("http://ollama.internal:8080")

      expect(described_class.infer_provider(uri)).to eq(:ollama)
    end

    it "infers llama_cpp from hostname containing llama" do
      uri = URI("http://llama-server.local:8080")

      expect(described_class.infer_provider(uri)).to eq(:llama_cpp)
    end

    it "defaults to openai_compatible for unknown" do
      uri = URI("http://unknown-server:9999")

      expect(described_class.infer_provider(uri)).to eq(:openai_compatible)
    end

    it "is case insensitive for hostname matching" do
      uri = URI("http://OLLAMA.LOCAL:8080")

      expect(described_class.infer_provider(uri)).to eq(:ollama)
    end

    it "prefers port over hostname for matching" do
      # Port 1234 should match lm_studio even if host says ollama
      uri = URI("http://ollama-server:1234")

      expect(described_class.infer_provider(uri)).to eq(:lm_studio)
    end
  end

  describe ".split_url_and_key" do
    it "splits URL and API key" do
      url, key = described_class.split_url_and_key("http://localhost:8080|sk-key")

      expect(url).to eq("http://localhost:8080")
      expect(key).to eq("sk-key")
    end

    it "returns nil key when no pipe" do
      url, key = described_class.split_url_and_key("http://localhost:8080")

      expect(url).to eq("http://localhost:8080")
      expect(key).to be_nil
    end

    it "handles multiple pipes by taking first split" do
      url, key = described_class.split_url_and_key("http://localhost|key|extra")

      expect(url).to eq("http://localhost")
      expect(key).to eq("key|extra")
    end

    it "strips whitespace from key" do
      _, key = described_class.split_url_and_key("http://localhost| spaced-key ")

      expect(key).to eq("spaced-key")
    end

    it "returns nil for empty key after strip" do
      _, key = described_class.split_url_and_key("http://localhost|   ")

      expect(key).to be_nil
    end
  end

  describe ".build_endpoint" do
    it "builds endpoint hash from URI" do
      uri = URI("http://localhost:1234")

      endpoint = described_class.build_endpoint(uri, nil)

      expect(endpoint[:provider]).to eq(:lm_studio)
      expect(endpoint[:host]).to eq("localhost")
      expect(endpoint[:port]).to eq(1234)
      expect(endpoint[:tls]).to be false
      expect(endpoint[:api_key]).to be_nil
    end

    it "detects TLS from https scheme" do
      uri = URI("https://api.example.com:443")

      endpoint = described_class.build_endpoint(uri, "key")

      expect(endpoint[:tls]).to be true
      expect(endpoint[:api_key]).to eq("key")
    end

    it "uses default port 80 for HTTP when not specified" do
      uri = URI("http://localhost")

      endpoint = described_class.build_endpoint(uri, nil)

      expect(endpoint[:port]).to eq(80)
    end

    it "uses default port 443 for HTTPS when not specified" do
      uri = URI("https://example.com")

      endpoint = described_class.build_endpoint(uri, nil)

      expect(endpoint[:port]).to eq(443)
    end
  end

  describe ".provider_from_port" do
    it "maps port 1234 to lm_studio" do
      expect(described_class.provider_from_port(1234)).to eq(:lm_studio)
    end

    it "maps port 11434 to ollama" do
      expect(described_class.provider_from_port(11_434)).to eq(:ollama)
    end

    it "maps port 8000 to vllm" do
      expect(described_class.provider_from_port(8000)).to eq(:vllm)
    end

    it "returns nil for unknown ports" do
      expect(described_class.provider_from_port(9999)).to be_nil
    end
  end

  describe ".provider_from_host" do
    it "returns lm_studio for lmstudio host" do
      expect(described_class.provider_from_host("lmstudio.local")).to eq(:lm_studio)
    end

    it "returns lm_studio for lm-studio host" do
      expect(described_class.provider_from_host("lm-studio")).to eq(:lm_studio)
    end

    it "returns ollama for ollama host" do
      expect(described_class.provider_from_host("ollama.internal")).to eq(:ollama)
    end

    it "returns llama_cpp for llama host" do
      expect(described_class.provider_from_host("llama-server")).to eq(:llama_cpp)
    end

    it "returns nil for unknown hosts" do
      expect(described_class.provider_from_host("random-server")).to be_nil
    end

    it "is case insensitive" do
      expect(described_class.provider_from_host("OLLAMA")).to eq(:ollama)
    end
  end
end
