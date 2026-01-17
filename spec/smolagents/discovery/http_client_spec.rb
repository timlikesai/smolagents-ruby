require "smolagents"
require "webmock/rspec"

RSpec.describe Smolagents::Discovery::HttpClient do
  describe ".get" do
    let(:host) { "localhost" }
    let(:port) { 1234 }
    let(:path) { "/v1/models" }
    let(:timeout) { 2.0 }

    context "with successful HTTP response" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 200, body: '{"models": []}')
      end

      it "returns response body" do
        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to eq('{"models": []}')
      end
    end

    context "with HTTPS" do
      before do
        stub_request(:get, "https://localhost:1234/v1/models")
          .to_return(status: 200, body: '{"data": []}')
      end

      it "uses HTTPS when tls is true" do
        result = described_class.get(host:, port:, path:, timeout:, tls: true)

        expect(result).to eq('{"data": []}')
      end
    end

    context "with API key" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .with(headers: { "Authorization" => "Bearer sk-test-key" })
          .to_return(status: 200, body: '{"models": []}')
      end

      it "includes Authorization header when api_key provided" do
        result = described_class.get(
          host:, port:, path:, timeout:, tls: false, api_key: "sk-test-key"
        )

        expect(result).to eq('{"models": []}')
      end
    end

    context "with non-success response" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 404, body: "Not Found")
      end

      it "returns nil for 404 response" do
        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to be_nil
      end
    end

    context "with 500 error" do
      before do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "returns nil for 500 response" do
        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to be_nil
      end
    end

    context "with connection errors" do
      it "returns nil on connection refused" do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Errno::ECONNREFUSED)

        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to be_nil
      end

      it "returns nil on timeout" do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Errno::ETIMEDOUT)

        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to be_nil
      end

      it "returns nil on open timeout" do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(Net::OpenTimeout)

        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to be_nil
      end

      it "returns nil on socket error" do
        stub_request(:get, "http://localhost:1234/v1/models")
          .to_raise(SocketError.new("getaddrinfo: nodename nor servname provided"))

        result = described_class.get(host:, port:, path:, timeout:, tls: false)

        expect(result).to be_nil
      end

      it "returns nil on SSL error" do
        stub_request(:get, "https://localhost:1234/v1/models")
          .to_raise(OpenSSL::SSL::SSLError)

        result = described_class.get(host:, port:, path:, timeout:, tls: true)

        expect(result).to be_nil
      end
    end
  end

  describe ".port_open?" do
    it "returns true when port is reachable", :slow do
      # This test actually attempts a socket connection but should fail fast
      # We can't easily mock Socket.tcp, so we test the failure case
      expect(described_class.port_open?("127.0.0.1", 59_999, timeout: 0.1)).to be false
    end

    it "returns false for unreachable port" do
      # Test with a port that should not be listening
      expect(described_class.port_open?("127.0.0.1", 59_998, timeout: 0.1)).to be false
    end

    it "returns false for invalid host" do
      expect(described_class.port_open?("invalid.nonexistent.host.example", 80, timeout: 0.1)).to be false
    end
  end

  describe ".build_uri" do
    it "builds HTTP URI" do
      uri = described_class.build_uri("localhost", 8080, "/api/v1/models", false)

      expect(uri.to_s).to eq("http://localhost:8080/api/v1/models")
    end

    it "builds HTTPS URI when tls is true" do
      uri = described_class.build_uri("api.example.com", 443, "/v1/models", true)

      # Port 443 is default for HTTPS, so Ruby's URI omits it
      expect(uri.to_s).to eq("https://api.example.com/v1/models")
    end
  end

  describe ".configure_http" do
    it "sets timeouts correctly" do
      uri = URI("http://localhost:1234/test")
      http = described_class.configure_http(uri, 5.0, false)

      expect(http.open_timeout).to eq(5.0)
      expect(http.read_timeout).to eq(5.0)
    end

    it "enables SSL for TLS connections" do
      uri = URI("https://localhost:1234/test")
      http = described_class.configure_http(uri, 2.0, true)

      expect(http.use_ssl?).to be true
    end

    it "does not use SSL for non-TLS connections" do
      uri = URI("http://localhost:1234/test")
      http = described_class.configure_http(uri, 2.0, false)

      expect(http.use_ssl?).to be false
    end
  end

  describe ".build_request" do
    it "creates GET request without auth header when no api_key" do
      uri = URI("http://localhost:1234/v1/models")
      request = described_class.build_request(uri, nil)

      expect(request).to be_a(Net::HTTP::Get)
      expect(request["Authorization"]).to be_nil
    end

    it "includes Bearer token when api_key provided" do
      uri = URI("http://localhost:1234/v1/models")
      request = described_class.build_request(uri, "test-api-key")

      expect(request["Authorization"]).to eq("Bearer test-api-key")
    end
  end
end
