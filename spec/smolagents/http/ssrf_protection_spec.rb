# Unit tests for SSRF protection utilities.
#
# These tests validate that the SSRF protection correctly blocks:
# - Cloud metadata endpoints (AWS, GCP, Azure)
# - Private/internal IP ranges (RFC 1918, loopback, link-local)
# - Invalid URL schemes

RSpec.describe Smolagents::Http::SsrfProtection do
  before { described_class.clear_validated_ips }
  after { described_class.clear_validated_ips }

  describe ".blocked_host?" do
    it "blocks AWS EC2 metadata endpoint" do
      expect(described_class.blocked_host?("169.254.169.254")).to be true
    end

    it "blocks AWS ECS metadata endpoint" do
      expect(described_class.blocked_host?("169.254.170.2")).to be true
    end

    it "blocks AWS IPv6 metadata endpoint" do
      expect(described_class.blocked_host?("fd00:ec2::254")).to be true
    end

    it "blocks GCP metadata endpoints" do
      expect(described_class.blocked_host?("metadata.google.internal")).to be true
      expect(described_class.blocked_host?("metadata.goog")).to be true
    end

    it "is case-insensitive" do
      expect(described_class.blocked_host?("METADATA.GOOGLE.INTERNAL")).to be true
    end

    it "allows normal hosts" do
      expect(described_class.blocked_host?("example.com")).to be false
      expect(described_class.blocked_host?("api.github.com")).to be false
    end

    it "handles nil gracefully" do
      expect(described_class.blocked_host?(nil)).to be false
    end
  end

  describe ".private_ip?" do
    context "IPv4 private ranges" do
      it "blocks RFC 1918 Class A (10.0.0.0/8)" do
        expect(described_class.private_ip?(IPAddr.new("10.0.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("10.255.255.255"))).to be true
      end

      it "blocks RFC 1918 Class B (172.16.0.0/12)" do
        expect(described_class.private_ip?(IPAddr.new("172.16.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("172.31.255.255"))).to be true
      end

      it "blocks RFC 1918 Class C (192.168.0.0/16)" do
        expect(described_class.private_ip?(IPAddr.new("192.168.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("192.168.255.255"))).to be true
      end

      it "blocks loopback (127.0.0.0/8)" do
        expect(described_class.private_ip?(IPAddr.new("127.0.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("127.255.255.255"))).to be true
      end

      it "blocks link-local (169.254.0.0/16)" do
        expect(described_class.private_ip?(IPAddr.new("169.254.0.1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("169.254.169.254"))).to be true
      end
    end

    context "IPv6 private ranges" do
      it "blocks IPv6 loopback (::1)" do
        expect(described_class.private_ip?(IPAddr.new("::1"))).to be true
      end

      it "blocks IPv6 unique local (fc00::/7)" do
        expect(described_class.private_ip?(IPAddr.new("fc00::1"))).to be true
        expect(described_class.private_ip?(IPAddr.new("fd00::1"))).to be true
      end

      it "blocks IPv6 link-local (fe80::/10)" do
        expect(described_class.private_ip?(IPAddr.new("fe80::1"))).to be true
      end
    end

    context "public IPs" do
      it "allows public IPv4 addresses" do
        expect(described_class.private_ip?(IPAddr.new("8.8.8.8"))).to be false
        expect(described_class.private_ip?(IPAddr.new("1.1.1.1"))).to be false
        expect(described_class.private_ip?(IPAddr.new("142.250.80.46"))).to be false
      end

      it "allows public IPv6 addresses" do
        expect(described_class.private_ip?(IPAddr.new("2001:4860:4860::8888"))).to be false
      end
    end
  end

  describe ".validate_scheme!" do
    it "allows http" do
      uri = URI.parse("http://example.com")
      expect { described_class.validate_scheme!(uri) }.not_to raise_error
    end

    it "allows https" do
      uri = URI.parse("https://example.com")
      expect { described_class.validate_scheme!(uri) }.not_to raise_error
    end

    it "blocks file scheme" do
      uri = URI.parse("file:///etc/passwd")
      expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme/)
    end

    it "blocks ftp scheme" do
      uri = URI.parse("ftp://example.com/file")
      expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme/)
    end

    it "blocks gopher scheme" do
      uri = URI.parse("gopher://example.com/")
      expect { described_class.validate_scheme!(uri) }.to raise_error(ArgumentError, /Invalid URL scheme/)
    end
  end

  describe ".validate_not_blocked!" do
    it "blocks AWS metadata endpoint" do
      uri = URI.parse("http://169.254.169.254/latest/meta-data/")
      expect { described_class.validate_not_blocked!(uri) }.to raise_error(ArgumentError, /Blocked host/)
    end

    it "blocks GCP metadata endpoint" do
      uri = URI.parse("http://metadata.google.internal/computeMetadata/v1/")
      expect { described_class.validate_not_blocked!(uri) }.to raise_error(ArgumentError, /Blocked host/)
    end

    it "allows normal hosts" do
      uri = URI.parse("https://api.github.com/repos")
      expect { described_class.validate_not_blocked!(uri) }.not_to raise_error
    end
  end

  describe ".resolve_and_validate_ip" do
    context "with public IPs" do
      before do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
      end

      it "returns the first resolved IP" do
        uri = URI.parse("https://example.com")
        result = described_class.resolve_and_validate_ip(uri)

        expect(result).to eq("93.184.216.34")
      end

      it "caches the validated IP" do
        uri = URI.parse("https://example.com")
        described_class.resolve_and_validate_ip(uri)

        expect(described_class.validated_ips["example.com"]).to eq("93.184.216.34")
      end
    end

    context "with private IPs" do
      before do
        allow(Resolv).to receive(:getaddresses).with("internal.local").and_return(["192.168.1.1"])
      end

      it "raises when any IP resolves to private range" do
        uri = URI.parse("http://internal.local")

        expect { described_class.resolve_and_validate_ip(uri) }
          .to raise_error(ArgumentError, %r{Private/internal IP addresses not allowed})
      end
    end

    context "with mixed public/private IPs" do
      before do
        allow(Resolv).to receive(:getaddresses).with("mixed.example.com")
                                               .and_return(["93.184.216.34", "10.0.0.1"])
      end

      it "raises if any IP is private" do
        uri = URI.parse("http://mixed.example.com")

        expect { described_class.resolve_and_validate_ip(uri) }
          .to raise_error(ArgumentError, %r{Private/internal IP addresses not allowed})
      end
    end

    context "with DNS failure" do
      before do
        allow(Resolv).to receive(:getaddresses).with("nonexistent.invalid").and_return([])
      end

      it "raises ResolvError for empty results" do
        uri = URI.parse("http://nonexistent.invalid")

        expect { described_class.resolve_and_validate_ip(uri) }
          .to raise_error(Resolv::ResolvError, /No addresses found/)
      end
    end
  end

  describe ".validated_ips" do
    it "is thread-local" do
      described_class.validated_ips["main"] = "1.2.3.4"

      thread_ips = Thread.new { described_class.validated_ips }.value

      expect(thread_ips).to eq({})
    end
  end

  describe ".clear_validated_ips" do
    it "clears cached IPs" do
      described_class.validated_ips["example.com"] = "1.2.3.4"

      described_class.clear_validated_ips

      expect(described_class.validated_ips).to eq({})
    end
  end
end
