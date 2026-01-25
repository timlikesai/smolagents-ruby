# Unit tests for DNS rebinding attack prevention middleware.
#
# DNS rebinding is a TOCTOU attack where a malicious DNS server returns
# different IPs for the same hostname between validation and connection time.

RSpec.describe Smolagents::Http::DnsRebindingGuard do
  let(:app) { ->(env) { Faraday::Response.new(status: 200, body: "OK") } }
  let(:resolved_ip) { "93.184.216.34" }
  let(:middleware) { described_class.new(app, resolved_ip:) }

  def build_env(url)
    Faraday::Env.from(
      method: :get,
      url: URI.parse(url),
      request_headers: {}
    )
  end

  describe "#call" do
    context "when resolved_ip is provided" do
      context "with same IP at connection time" do
        before do
          allow(Resolv).to receive(:getaddresses).with("example.com").and_return([resolved_ip])
        end

        it "allows the request" do
          env = build_env("https://example.com/path")

          response = middleware.call(env)

          expect(response.status).to eq(200)
        end
      end

      context "with different public IP at connection time" do
        before do
          allow(Resolv).to receive(:getaddresses).with("example.com")
                                                 .and_return(["104.16.132.229"])
        end

        it "allows the request (public IP is safe)" do
          env = build_env("https://example.com/path")

          response = middleware.call(env)

          expect(response.status).to eq(200)
        end
      end

      context "with DNS rebind to private IP" do
        before do
          allow(Resolv).to receive(:getaddresses).with("evil.com")
                                                 .and_return(["192.168.1.1"])
        end

        it "raises ForbiddenError" do
          env = build_env("https://evil.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
        end

        it "includes hostname in error message" do
          env = build_env("https://evil.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /evil\.com/)
        end

        it "includes private IP in error message" do
          env = build_env("https://evil.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /192\.168\.1\.1/)
        end
      end

      context "with DNS rebind to loopback" do
        before do
          allow(Resolv).to receive(:getaddresses).with("localhost-rebind.com")
                                                 .and_return(["127.0.0.1"])
        end

        it "raises ForbiddenError" do
          env = build_env("https://localhost-rebind.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
        end
      end

      context "with DNS rebind to cloud metadata IP" do
        before do
          allow(Resolv).to receive(:getaddresses).with("metadata-rebind.com")
                                                 .and_return(["169.254.169.254"])
        end

        it "raises ForbiddenError" do
          env = build_env("https://metadata-rebind.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
        end
      end

      context "with multiple IPs including private" do
        before do
          allow(Resolv).to receive(:getaddresses).with("multi.example.com")
                                                 .and_return(["93.184.216.34", "10.0.0.1"])
        end

        it "raises ForbiddenError for any private IP" do
          env = build_env("https://multi.example.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
        end
      end

      context "with DNS resolution failure" do
        before do
          allow(Resolv).to receive(:getaddresses).with("failing.com")
                                                 .and_raise(Resolv::ResolvError, "DNS lookup failed")
        end

        it "raises ForbiddenError" do
          env = build_env("https://failing.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /DNS resolution failed/)
        end
      end

      context "with empty DNS response" do
        before do
          allow(Resolv).to receive(:getaddresses).with("empty.com").and_return([])
        end

        it "raises ForbiddenError" do
          env = build_env("https://empty.com/path")

          expect { middleware.call(env) }
            .to raise_error(Faraday::ForbiddenError, /DNS resolution failed/)
        end
      end
    end

    context "when resolved_ip is nil" do
      let(:middleware) { described_class.new(app, resolved_ip: nil) }

      it "skips validation (for allow_private mode)" do
        env = build_env("https://internal.local/path")

        response = middleware.call(env)

        expect(response.status).to eq(200)
      end
    end
  end

  describe "IPv6 rebinding attacks" do
    let(:resolved_ip) { "2001:4860:4860::8888" }

    context "rebind to IPv6 loopback" do
      before do
        allow(Resolv).to receive(:getaddresses).with("ipv6-rebind.com")
                                               .and_return(["::1"])
      end

      it "raises ForbiddenError" do
        env = build_env("https://ipv6-rebind.com/path")

        expect { middleware.call(env) }
          .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
      end
    end

    context "rebind to IPv6 unique local" do
      before do
        allow(Resolv).to receive(:getaddresses).with("ipv6-fc00.com")
                                               .and_return(["fc00::1"])
      end

      it "raises ForbiddenError" do
        env = build_env("https://ipv6-fc00.com/path")

        expect { middleware.call(env) }
          .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
      end
    end

    context "rebind to IPv6 link-local" do
      before do
        allow(Resolv).to receive(:getaddresses).with("ipv6-fe80.com")
                                               .and_return(["fe80::1"])
      end

      it "raises ForbiddenError" do
        env = build_env("https://ipv6-fe80.com/path")

        expect { middleware.call(env) }
          .to raise_error(Faraday::ForbiddenError, /DNS rebinding detected/)
      end
    end
  end
end
