# -- testing Faraday middleware with mock interfaces
require "webmock/rspec"
require "resolv"
require "ipaddr"

RSpec.describe Smolagents::Http do
  describe "module structure" do
    it "loads all submodules" do
      expect(described_class::UserAgent).to be_a(Class)
      expect(described_class::SsrfProtection).to be_a(Module)
      expect(described_class::DnsRebindingGuard).to be_a(Class)
      expect(described_class::Connection).to be_a(Module)
      expect(described_class::Requests).to be_a(Module)
      expect(described_class::ResponseHandling).to be_a(Module)
    end
  end

  describe Smolagents::Http::SsrfProtection do
    before { described_class.clear_validated_ips }

    describe "BLOCKED_HOSTS" do
      it "includes AWS EC2 metadata endpoint" do
        expect(described_class::BLOCKED_HOSTS).to include("169.254.169.254")
      end

      it "includes AWS ECS metadata endpoint" do
        expect(described_class::BLOCKED_HOSTS).to include("169.254.170.2")
      end

      it "includes AWS IPv6 metadata endpoint" do
        expect(described_class::BLOCKED_HOSTS).to include("fd00:ec2::254")
      end

      it "includes GCP metadata endpoints" do
        expect(described_class::BLOCKED_HOSTS).to include("metadata.google.internal")
        expect(described_class::BLOCKED_HOSTS).to include("metadata.goog")
      end

      it "is frozen" do
        expect(described_class::BLOCKED_HOSTS).to be_frozen
      end
    end

    describe "PRIVATE_RANGES" do
      let(:ranges) { described_class::PRIVATE_RANGES }

      it "covers RFC 1918 Class A private range (10.0.0.0/8)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("10.0.0.1")) }).to be true
        expect(ranges.any? { |r| r.include?(IPAddr.new("10.255.255.255")) }).to be true
      end

      it "covers RFC 1918 Class B private range (172.16.0.0/12)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("172.16.0.1")) }).to be true
        expect(ranges.any? { |r| r.include?(IPAddr.new("172.31.255.255")) }).to be true
      end

      it "covers RFC 1918 Class C private range (192.168.0.0/16)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("192.168.0.1")) }).to be true
        expect(ranges.any? { |r| r.include?(IPAddr.new("192.168.255.255")) }).to be true
      end

      it "covers loopback range (127.0.0.0/8)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("127.0.0.1")) }).to be true
        expect(ranges.any? { |r| r.include?(IPAddr.new("127.255.255.255")) }).to be true
      end

      it "covers link-local range (169.254.0.0/16)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("169.254.0.1")) }).to be true
        expect(ranges.any? { |r| r.include?(IPAddr.new("169.254.255.255")) }).to be true
      end

      it "covers IPv6 loopback (::1/128)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("::1")) }).to be true
      end

      it "covers IPv6 unique local (fc00::/7)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("fc00::1")) }).to be true
        expect(ranges.any? { |r| r.include?(IPAddr.new("fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")) }).to be true
      end

      it "covers IPv6 link-local (fe80::/10)" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("fe80::1")) }).to be true
      end

      it "does not include public IPs" do
        expect(ranges.any? { |r| r.include?(IPAddr.new("8.8.8.8")) }).to be false
        expect(ranges.any? { |r| r.include?(IPAddr.new("93.184.216.34")) }).to be false
        expect(ranges.any? { |r| r.include?(IPAddr.new("1.1.1.1")) }).to be false
      end

      it "is frozen" do
        expect(ranges).to be_frozen
      end
    end

    describe ".validated_ips" do
      it "returns thread-local storage" do
        expect(described_class.validated_ips).to be_a(Hash)
      end

      it "is isolated per thread" do
        described_class.validated_ips["test.com"] = "1.2.3.4"

        thread_ips = Thread.new { described_class.validated_ips }.value

        expect(thread_ips).to eq({})
      end
    end

    describe ".clear_validated_ips" do
      it "clears the validated IPs cache" do
        described_class.validated_ips["test.com"] = "1.2.3.4"

        described_class.clear_validated_ips

        expect(described_class.validated_ips).to be_empty
      end
    end

    describe ".private_ip?" do
      it "returns true for private IPv4 addresses" do
        expect(described_class.private_ip?(IPAddr.new("10.0.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("172.16.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("192.168.1.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("127.0.0.1"))).to be true
      end

      it "returns true for private IPv6 addresses" do
        expect(described_class.private_ip?(IPAddr.new("::1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("fc00::1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("fe80::1"))).to be true
      end

      it "returns false for public IP addresses" do
        expect(described_class.private_ip?(IPAddr.new("8.8.8.8"))).to be false
        expect(described_class.private_ip?(IPAddr.new("93.184.216.34"))).to be false
        expect(described_class.private_ip?(IPAddr.new("2001:4860:4860::8888"))).to be false
      end
    end

    describe ".blocked_host?" do
      it "returns true for cloud metadata endpoints" do
        expect(described_class.blocked_host?("169.254.169.254")).to be true
        expect(described_class.blocked_host?("metadata.google.internal")).to be true
      end

      it "returns false for normal hosts" do
        expect(described_class.blocked_host?("example.com")).to be false
        expect(described_class.blocked_host?("api.github.com")).to be false
      end

      it "is case insensitive" do
        expect(described_class.blocked_host?("METADATA.GOOGLE.INTERNAL")).to be true
        expect(described_class.blocked_host?("Metadata.Google.Internal")).to be true
      end

      it "handles nil gracefully" do
        expect(described_class.blocked_host?(nil)).to be false
      end
    end

    describe ".validate_scheme!" do
      it "allows http scheme" do
        uri = URI.parse("http://example.com")
        expect { described_class.validate_scheme!(uri) }.not_to raise_error
      end

      it "allows https scheme" do
        uri = URI.parse("https://example.com")
        expect { described_class.validate_scheme!(uri) }.not_to raise_error
      end

      it "rejects ftp scheme" do
        uri = URI.parse("ftp://example.com")
        expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme: ftp/)
      end

      it "rejects file scheme" do
        uri = URI.parse("file:///etc/passwd")
        expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme: file/)
      end

      it "rejects javascript scheme" do
        # URI.parse doesn't handle javascript: well, but we test the error
        uri = double("uri", scheme: "javascript")
        expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme/)
      end

      it "rejects data scheme" do
        uri = double("uri", scheme: "data")
        expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme/)
      end
    end

    describe ".validate_not_blocked!" do
      it "allows normal hosts" do
        uri = URI.parse("https://example.com")
        expect { described_class.validate_not_blocked!(uri) }.not_to raise_error
      end

      it "raises for AWS EC2 metadata endpoint" do
        uri = URI.parse("http://169.254.169.254/latest/meta-data/")
        expect { described_class.validate_not_blocked!(uri) }.to raise_error(ArgumentError, /Blocked host/)
      end

      it "raises for GCP metadata endpoint" do
        uri = URI.parse("http://metadata.google.internal/computeMetadata/v1/")
        expect { described_class.validate_not_blocked!(uri) }.to raise_error(ArgumentError, /Blocked host/)
      end
    end

    describe ".resolve_and_validate_ip" do
      it "resolves hostname and returns first IP" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])

        result = described_class.resolve_and_validate_ip(URI.parse("https://example.com"))

        expect(result).to eq("93.184.216.34")
      end

      it "caches the first resolved IP" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34", "93.184.216.35"])

        described_class.resolve_and_validate_ip(URI.parse("https://example.com"))

        expect(described_class.validated_ips["example.com"]).to eq("93.184.216.34")
      end

      it "raises for private IP resolution" do
        allow(Resolv).to receive(:getaddresses).with("internal.example.com").and_return(["192.168.1.1"])

        expect do
          described_class.resolve_and_validate_ip(URI.parse("https://internal.example.com"))
        end.to raise_error(ArgumentError, /Private.*not allowed/)
      end

      it "raises for localhost resolution" do
        allow(Resolv).to receive(:getaddresses).with("localhost").and_return(["127.0.0.1"])

        expect do
          described_class.resolve_and_validate_ip(URI.parse("http://localhost"))
        end.to raise_error(ArgumentError, /Private.*not allowed/)
      end

      it "raises on DNS resolution failure" do
        allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError)

        expect do
          described_class.resolve_and_validate_ip(URI.parse("https://nonexistent.invalid"))
        end.to raise_error(Resolv::ResolvError)
      end

      it "raises when no addresses found" do
        allow(Resolv).to receive(:getaddresses).with("empty.invalid").and_return([])

        expect do
          described_class.resolve_and_validate_ip(URI.parse("https://empty.invalid"))
        end.to raise_error(Resolv::ResolvError, /No addresses found/)
      end

      context "with multi-IP DNS records" do
        it "validates ALL IPs and allows when all are public" do
          allow(Resolv).to receive(:getaddresses).with("multi.example.com")
                                                 .and_return(["93.184.216.34", "93.184.216.35", "8.8.8.8"])

          result = described_class.resolve_and_validate_ip(URI.parse("https://multi.example.com"))

          expect(result).to eq("93.184.216.34")
        end

        it "raises when ANY IP is private (first public, second private)" do
          allow(Resolv).to receive(:getaddresses).with("mixed.example.com")
                                                 .and_return(["93.184.216.34", "192.168.1.1"])

          expect do
            described_class.resolve_and_validate_ip(URI.parse("https://mixed.example.com"))
          end.to raise_error(ArgumentError, /Private.*not allowed.*192\.168\.1\.1/)
        end

        it "raises when ANY IP is private (first private)" do
          allow(Resolv).to receive(:getaddresses).with("evil.example.com")
                                                 .and_return(["10.0.0.1", "93.184.216.34"])

          expect do
            described_class.resolve_and_validate_ip(URI.parse("https://evil.example.com"))
          end.to raise_error(ArgumentError, /Private.*not allowed.*10\.0\.0\.1/)
        end

        it "raises when ANY IP is link-local (cloud metadata attack)" do
          allow(Resolv).to receive(:getaddresses).with("attacker.com")
                                                 .and_return(["93.184.216.34", "169.254.169.254"])

          expect do
            described_class.resolve_and_validate_ip(URI.parse("https://attacker.com"))
          end.to raise_error(ArgumentError, /Private.*not allowed.*169\.254\.169\.254/)
        end
      end
    end
  end

  describe Smolagents::Http::DnsRebindingGuard do
    let(:app) { double("app") }

    describe "#initialize" do
      it "stores the resolved IP" do
        guard = described_class.new(app, resolved_ip: "1.2.3.4")

        expect(guard.instance_variable_get(:@resolved_ip)).to eq("1.2.3.4")
      end

      it "accepts nil resolved_ip" do
        guard = described_class.new(app, resolved_ip: nil)

        expect(guard.instance_variable_get(:@resolved_ip)).to be_nil
      end
    end

    describe "#call" do
      let(:env) { double("env", url: URI.parse("https://example.com/path")) }

      it "passes through when resolved_ip is nil" do
        guard = described_class.new(app, resolved_ip: nil)
        allow(app).to receive(:call).with(env).and_return(double("response"))

        expect { guard.call(env) }.not_to raise_error
      end

      it "passes through when IP matches" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        allow(app).to receive(:call).with(env).and_return(double("response"))

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.not_to raise_error
      end

      it "passes through when IP changes to another public IP" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.35"])
        allow(app).to receive(:call).with(env).and_return(double("response"))

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.not_to raise_error
      end

      it "raises ForbiddenError when IP changes to private address" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["192.168.1.1"])

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
      end

      it "raises ForbiddenError when IP changes to localhost" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["127.0.0.1"])

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
      end

      it "raises ForbiddenError when IP changes to link-local" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["169.254.169.254"])

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
      end

      it "includes hostname and IP in error message" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["192.168.1.1"])

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /example\.com.*192\.168\.1\.1/)
      end

      it "raises ForbiddenError on DNS resolution failure" do
        allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError)

        guard = described_class.new(app, resolved_ip: "93.184.216.34")

        expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /DNS resolution failed/)
      end

      context "with multi-IP DNS records" do
        it "passes when all IPs are public" do
          allow(Resolv).to receive(:getaddresses).with("example.com")
                                                 .and_return(["93.184.216.34", "93.184.216.35", "8.8.8.8"])
          allow(app).to receive(:call).with(env).and_return(double("response"))

          guard = described_class.new(app, resolved_ip: "93.184.216.34")

          expect { guard.call(env) }.not_to raise_error
        end

        it "raises when ANY IP is private (public then private)" do
          allow(Resolv).to receive(:getaddresses).with("example.com")
                                                 .and_return(["93.184.216.34", "192.168.1.1"])

          guard = described_class.new(app, resolved_ip: "93.184.216.34")

          expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /192\.168\.1\.1/)
        end

        it "raises when ANY IP is private (private first)" do
          allow(Resolv).to receive(:getaddresses).with("example.com")
                                                 .and_return(["10.0.0.1", "93.184.216.35"])

          guard = described_class.new(app, resolved_ip: "93.184.216.34")

          expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /10\.0\.0\.1/)
        end

        it "detects DNS rebinding with cloud metadata in multi-IP response" do
          allow(Resolv).to receive(:getaddresses).with("example.com")
                                                 .and_return(["93.184.216.34", "169.254.169.254"])

          guard = described_class.new(app, resolved_ip: "93.184.216.34")

          expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /169\.254\.169\.254/)
        end
      end
    end
  end

  describe Smolagents::Http::Connection do
    let(:test_class) do
      Class.new do
        include Smolagents::Http::Connection
      end
    end
    let(:instance) { test_class.new }

    describe "constants" do
      it "defines DEFAULT_TIMEOUT" do
        expect(described_class::DEFAULT_TIMEOUT).to eq(30)
      end

      it "defines DEFAULT_USER_AGENT" do
        expect(described_class::DEFAULT_USER_AGENT).to be_a(Smolagents::Http::UserAgent)
        expect(described_class::DEFAULT_USER_AGENT).to be_frozen
      end

      it "defines DEFAULT_HEADERS" do
        expect(described_class::DEFAULT_HEADERS).to include("Accept" => "*/*")
        expect(described_class::DEFAULT_HEADERS).to include("Accept-Language")
        expect(described_class::DEFAULT_HEADERS).to include("Connection")
        # NOTE: Accept-Encoding is NOT set - Faraday's net_http adapter handles
        # gzip/deflate automatically when the header isn't explicitly set.
        expect(described_class::DEFAULT_HEADERS).not_to include("Accept-Encoding")
        expect(described_class::DEFAULT_HEADERS).to be_frozen
      end
    end

    describe "#user_agent" do
      it "can be set and read" do
        instance.user_agent = "TestAgent/1.0"

        expect(instance.user_agent).to eq("TestAgent/1.0")
      end

      it "accepts UserAgent objects" do
        ua = Smolagents::Http::UserAgent.new(tool_name: "TestTool")
        instance.user_agent = ua

        expect(instance.user_agent).to eq(ua)
      end
    end

    describe "#close_connections" do
      it "closes all cached connections" do
        # Create a connection first
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:get, "https://example.com/").to_return(status: 200)

        # Access connection to create cache
        instance.send(:connection, "https://example.com", resolved_ip: "93.184.216.34")

        # Should not raise when closing
        expect { instance.send(:close_connections) }.not_to raise_error
      end

      it "handles case when no connections exist" do
        expect { instance.send(:close_connections) }.not_to raise_error
      end
    end
  end

  describe Smolagents::Http::Requests do
    let(:test_class) do
      Class.new do
        include Smolagents::Http::Requests
      end
    end
    let(:client) { test_class.new }

    before { Smolagents::Http::SsrfProtection.clear_validated_ips }

    describe "#get" do
      it "makes GET request to URL" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:get, "https://example.com/api").to_return(status: 200, body: "response")

        response = client.get("https://example.com/api")

        expect(response.status).to eq(200)
        expect(response.body).to eq("response")
      end

      it "appends query parameters" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:get, "https://example.com/search?q=test&limit=10").to_return(status: 200)

        response = client.get("https://example.com/search", params: { q: "test", limit: 10 })

        expect(response.status).to eq(200)
      end

      it "adds custom headers" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:get, "https://example.com/api")
          .with(headers: { "X-Custom" => "value" })
          .to_return(status: 200)

        response = client.get("https://example.com/api", headers: { "X-Custom" => "value" })

        expect(response.status).to eq(200)
      end

      it "validates URL before making request" do
        expect { client.get("ftp://example.com") }.to raise_error(ArgumentError, /Invalid URL scheme/)
      end

      it "blocks cloud metadata endpoints" do
        expect { client.get("http://169.254.169.254/latest/meta-data/") }.to raise_error(ArgumentError, /Blocked host/)
      end

      it "blocks private IPs by default" do
        allow(Resolv).to receive(:getaddresses).with("localhost").and_return(["127.0.0.1"])

        expect { client.get("http://localhost/") }.to raise_error(ArgumentError, /Private/)
      end

      it "allows private IPs when allow_private is true" do
        allow(Resolv).to receive(:getaddresses).with("localhost").and_return(["127.0.0.1"])
        stub_request(:get, "http://localhost/").to_return(status: 200)

        response = client.get("http://localhost/", allow_private: true)

        expect(response.status).to eq(200)
      end
    end

    describe "#post" do
      it "makes POST request to URL" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:post, "https://example.com/api").to_return(status: 201)

        response = client.post("https://example.com/api")

        expect(response.status).to eq(201)
      end

      it "sends raw body" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:post, "https://example.com/api")
          .with(body: "raw content")
          .to_return(status: 200)

        response = client.post("https://example.com/api", body: "raw content")

        expect(response.status).to eq(200)
      end

      it "sends JSON body with correct Content-Type" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:post, "https://example.com/api")
          .with(
            body: '{"key":"value"}',
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200)

        response = client.post("https://example.com/api", json: { key: "value" })

        expect(response.status).to eq(200)
      end

      it "sends form body with correct Content-Type" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:post, "https://example.com/api")
          .with(
            body: "name=test&value=123",
            headers: { "Content-Type" => "application/x-www-form-urlencoded" }
          )
          .to_return(status: 200)

        response = client.post("https://example.com/api", form: { name: "test", value: 123 })

        expect(response.status).to eq(200)
      end

      it "adds custom headers" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:post, "https://example.com/api")
          .with(headers: { "Authorization" => "Bearer token" })
          .to_return(status: 200)

        response = client.post("https://example.com/api", headers: { "Authorization" => "Bearer token" })

        expect(response.status).to eq(200)
      end

      it "validates URL before making request" do
        expect { client.post("ftp://example.com") }.to raise_error(ArgumentError, /Invalid URL scheme/)
      end

      it "allows private IPs when allow_private is true" do
        allow(Resolv).to receive(:getaddresses).with("localhost").and_return(["127.0.0.1"])
        stub_request(:post, "http://localhost/api").to_return(status: 200)

        response = client.post("http://localhost/api", allow_private: true)

        expect(response.status).to eq(200)
      end
    end

    describe "#validate_url!" do
      it "returns resolved IP for valid public URL" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])

        result = client.validate_url!("https://example.com")

        expect(result).to eq("93.184.216.34")
      end

      it "returns nil when allow_private is true" do
        result = client.validate_url!("https://example.com", allow_private: true)

        expect(result).to be_nil
      end

      it "raises for invalid schemes" do
        expect { client.validate_url!("ftp://example.com") }.to raise_error(ArgumentError)
      end

      it "raises for blocked hosts" do
        expect { client.validate_url!("http://169.254.169.254") }.to raise_error(ArgumentError)
      end

      it "raises for private IP resolution" do
        allow(Resolv).to receive(:getaddresses).with("internal.local").and_return(["10.0.0.1"])

        expect { client.validate_url!("http://internal.local") }.to raise_error(ArgumentError, /Private/)
      end
    end
  end
end
