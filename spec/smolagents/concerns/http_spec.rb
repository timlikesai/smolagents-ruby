require "webmock/rspec"

RSpec.describe Smolagents::Concerns::Http do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Http
    end
  end

  let(:http_client) { test_class.new }

  before do
    described_class.clear_validated_ips
  end

  describe ".validate_url!" do
    it "allows valid HTTPS URLs" do
      allow(Resolv).to receive(:getaddress).with("example.com").and_return("93.184.216.34")

      expect { http_client.validate_url!("https://example.com") }.not_to raise_error
    end

    it "allows valid HTTP URLs" do
      allow(Resolv).to receive(:getaddress).with("example.com").and_return("93.184.216.34")

      expect { http_client.validate_url!("http://example.com") }.not_to raise_error
    end

    it "rejects non-HTTP schemes" do
      expect { http_client.validate_url!("ftp://example.com") }.to raise_error(ArgumentError, /Invalid URL scheme/)
      expect { http_client.validate_url!("file:///etc/passwd") }.to raise_error(ArgumentError, /Invalid URL scheme/)
    end

    it "rejects blocked hosts" do
      expect { http_client.validate_url!("http://169.254.169.254") }.to raise_error(ArgumentError, /Blocked host/)
      expect { http_client.validate_url!("http://metadata.google.internal") }.to raise_error(ArgumentError, /Blocked host/)
    end

    it "rejects private IP addresses" do
      allow(Resolv).to receive(:getaddress).with("internal.example.com").and_return("192.168.1.1")

      expect { http_client.validate_url!("http://internal.example.com") }.to raise_error(ArgumentError, /Private/)
    end

    it "rejects localhost" do
      allow(Resolv).to receive(:getaddress).with("localhost").and_return("127.0.0.1")

      expect { http_client.validate_url!("http://localhost") }.to raise_error(ArgumentError, /Private/)
    end

    it "allows private IPs when allow_private is true" do
      allow(Resolv).to receive(:getaddress).with("localhost").and_return("127.0.0.1")

      expect { http_client.validate_url!("http://localhost", allow_private: true) }.not_to raise_error
    end

    it "stores validated IP for TOCTOU protection" do
      allow(Resolv).to receive(:getaddress).with("example.com").and_return("93.184.216.34")

      http_client.validate_url!("https://example.com")

      expect(described_class.validated_ips["example.com"]).to eq("93.184.216.34")
    end

    it "returns the resolved IP" do
      allow(Resolv).to receive(:getaddress).with("example.com").and_return("93.184.216.34")

      result = http_client.validate_url!("https://example.com")

      expect(result).to eq("93.184.216.34")
    end

    it "returns nil when allow_private is true" do
      result = http_client.validate_url!("https://example.com", allow_private: true)

      expect(result).to be_nil
    end
  end

  describe "DnsRebindingGuard middleware" do
    let(:middleware) { Smolagents::Concerns::Http::DnsRebindingGuard }

    it "allows requests when IP matches" do
      app = double("app") # rubocop:disable RSpec/VerifiedDoubles -- Faraday middleware interface
      env = double("env", url: URI.parse("https://example.com/path")) # rubocop:disable RSpec/VerifiedDoubles -- Faraday request environment

      allow(Resolv).to receive(:getaddress).with("example.com").and_return("93.184.216.34")
      allow(app).to receive(:call).with(env).and_return(double("response")) # rubocop:disable RSpec/VerifiedDoubles -- Faraday response

      guard = middleware.new(app, resolved_ip: "93.184.216.34")
      expect { guard.call(env) }.not_to raise_error
    end

    it "allows requests when IP changes to another public IP" do
      app = double("app") # rubocop:disable RSpec/VerifiedDoubles -- Faraday middleware interface
      env = double("env", url: URI.parse("https://example.com/path")) # rubocop:disable RSpec/VerifiedDoubles -- Faraday request environment

      # IP changed but still public
      allow(Resolv).to receive(:getaddress).with("example.com").and_return("93.184.216.35")
      allow(app).to receive(:call).with(env).and_return(double("response")) # rubocop:disable RSpec/VerifiedDoubles -- Faraday response

      guard = middleware.new(app, resolved_ip: "93.184.216.34")
      expect { guard.call(env) }.not_to raise_error
    end

    it "raises error when IP changes to private address" do
      app = double("app") # rubocop:disable RSpec/VerifiedDoubles -- Faraday middleware interface
      env = double("env", url: URI.parse("https://example.com/path")) # rubocop:disable RSpec/VerifiedDoubles -- Faraday request environment

      # DNS rebinding attack - IP changed to private address
      allow(Resolv).to receive(:getaddress).with("example.com").and_return("192.168.1.1")

      guard = middleware.new(app, resolved_ip: "93.184.216.34")
      expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
    end

    it "raises error when IP changes to localhost" do
      app = double("app") # rubocop:disable RSpec/VerifiedDoubles -- Faraday middleware interface
      env = double("env", url: URI.parse("https://example.com/path")) # rubocop:disable RSpec/VerifiedDoubles -- Faraday request environment

      allow(Resolv).to receive(:getaddress).with("example.com").and_return("127.0.0.1")

      guard = middleware.new(app, resolved_ip: "93.184.216.34")
      expect { guard.call(env) }.to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
    end
  end

  describe "PRIVATE_RANGES" do
    let(:ranges) { Smolagents::Concerns::Http::PRIVATE_RANGES }

    it "includes 10.0.0.0/8" do
      expect(ranges.any? { |r| r.include?(IPAddr.new("10.0.0.1")) }).to be true
      expect(ranges.any? { |r| r.include?(IPAddr.new("10.255.255.255")) }).to be true
    end

    it "includes 172.16.0.0/12" do
      expect(ranges.any? { |r| r.include?(IPAddr.new("172.16.0.1")) }).to be true
      expect(ranges.any? { |r| r.include?(IPAddr.new("172.31.255.255")) }).to be true
    end

    it "includes 192.168.0.0/16" do
      expect(ranges.any? { |r| r.include?(IPAddr.new("192.168.0.1")) }).to be true
      expect(ranges.any? { |r| r.include?(IPAddr.new("192.168.255.255")) }).to be true
    end

    it "includes localhost" do
      expect(ranges.any? { |r| r.include?(IPAddr.new("127.0.0.1")) }).to be true
    end

    it "includes IPv6 localhost" do
      expect(ranges.any? { |r| r.include?(IPAddr.new("::1")) }).to be true
    end

    it "excludes public IPs" do
      expect(ranges.any? { |r| r.include?(IPAddr.new("8.8.8.8")) }).to be false
      expect(ranges.any? { |r| r.include?(IPAddr.new("93.184.216.34")) }).to be false
    end
  end
end
