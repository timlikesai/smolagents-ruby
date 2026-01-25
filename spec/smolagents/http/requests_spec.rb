# Unit tests for HTTP request methods with SSRF protection.
#
# Tests the integration of SSRF protection, DNS rebinding guard,
# and HTTP request functionality.

RSpec.describe Smolagents::Http::Requests do
  # Mock request class that simulates Faraday request yielded in block.
  # Uses Struct because we need mutable params/headers/body (Data.define is immutable).
  # rubocop:disable Smolagents/PreferDataDefine
  MockRequest = Struct.new(:params, :headers, :body) do
    def initialize
      super({}, {}, nil)
    end
  end
  # rubocop:enable Smolagents/PreferDataDefine

  let(:test_class) do
    Class.new do
      include Smolagents::Http::Requests

      attr_accessor :timeout

      def initialize
        @timeout = nil
        @user_agent = nil
      end
    end
  end
  let(:instance) { test_class.new }
  let(:mock_request) { MockRequest.new }

  before do
    Smolagents::Http::SsrfProtection.clear_validated_ips
  end

  after do
    Smolagents::Http::SsrfProtection.clear_validated_ips
  end

  describe "#validate_url!" do
    context "scheme validation" do
      it "allows http URLs" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])

        result = instance.validate_url!("http://example.com")

        expect(result).to eq("93.184.216.34")
      end

      it "allows https URLs" do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])

        result = instance.validate_url!("https://example.com")

        expect(result).to eq("93.184.216.34")
      end

      it "blocks file URLs" do
        expect { instance.validate_url!("file:///etc/passwd") }
          .to raise_error(ArgumentError, /Invalid URL scheme/)
      end

      it "blocks ftp URLs" do
        expect { instance.validate_url!("ftp://ftp.example.com/file") }
          .to raise_error(ArgumentError, /Invalid URL scheme/)
      end
    end

    context "blocked host validation" do
      it "blocks AWS metadata endpoint" do
        expect { instance.validate_url!("http://169.254.169.254/latest/meta-data/") }
          .to raise_error(ArgumentError, /Blocked host/)
      end

      it "blocks GCP metadata endpoint" do
        expect { instance.validate_url!("http://metadata.google.internal/computeMetadata/v1/") }
          .to raise_error(ArgumentError, /Blocked host/)
      end
    end

    context "IP validation" do
      it "blocks private IPs" do
        allow(Resolv).to receive(:getaddresses).with("internal.local")
                                               .and_return(["192.168.1.1"])

        expect { instance.validate_url!("http://internal.local") }
          .to raise_error(ArgumentError, %r{Private/internal IP addresses not allowed})
      end

      it "blocks localhost" do
        allow(Resolv).to receive(:getaddresses).with("localhost")
                                               .and_return(["127.0.0.1"])

        expect { instance.validate_url!("http://localhost") }
          .to raise_error(ArgumentError, %r{Private/internal IP addresses not allowed})
      end
    end

    context "with allow_private: true" do
      it "returns nil without validating IP" do
        result = instance.validate_url!("http://192.168.1.1", allow_private: true)

        expect(result).to be_nil
      end

      it "still validates scheme" do
        expect { instance.validate_url!("file:///etc/passwd", allow_private: true) }
          .to raise_error(ArgumentError, /Invalid URL scheme/)
      end

      it "still validates blocked hosts" do
        expect { instance.validate_url!("http://169.254.169.254/", allow_private: true) }
          .to raise_error(ArgumentError, /Blocked host/)
      end
    end
  end

  describe "#get" do
    let(:mock_response) { instance_double(Faraday::Response, status: 200, body: "OK") }
    let(:mock_connection) { instance_double(Faraday::Connection) }

    before do
      allow(Resolv).to receive(:getaddresses).with("api.example.com")
                                             .and_return(["93.184.216.34"])
      allow(instance).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:get).and_yield(mock_request).and_return(mock_response)
    end

    it "makes GET request to validated URL" do
      response = instance.get("https://api.example.com/data")

      expect(response.status).to eq(200)
    end

    it "validates URL before making request" do
      allow(Resolv).to receive(:getaddresses).with("internal.local")
                                             .and_return(["10.0.0.1"])

      expect { instance.get("http://internal.local/secret") }
        .to raise_error(ArgumentError, %r{Private/internal IP})
    end

    it "passes params to request" do
      instance.get("https://api.example.com", params: { q: "search" })

      expect(mock_request.params[:q]).to eq("search")
    end

    it "passes headers to request" do
      instance.get("https://api.example.com", headers: { "Authorization" => "Bearer token" })

      expect(mock_request.headers["Authorization"]).to eq("Bearer token")
    end

    it "passes timeout to connection" do
      allow(instance).to receive(:connection)
        .with("https://api.example.com", hash_including(timeout: 60))
        .and_return(mock_connection)

      instance.get("https://api.example.com", timeout: 60)

      expect(instance).to have_received(:connection)
        .with("https://api.example.com", hash_including(timeout: 60))
    end
  end

  describe "#post" do
    let(:mock_response) { instance_double(Faraday::Response, status: 201, body: '{"id": 1}') }
    let(:mock_connection) { instance_double(Faraday::Connection) }

    before do
      allow(Resolv).to receive(:getaddresses).with("api.example.com")
                                             .and_return(["93.184.216.34"])
      allow(instance).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:post).and_yield(mock_request).and_return(mock_response)
    end

    it "makes POST request to validated URL" do
      response = instance.post("https://api.example.com/data")

      expect(response.status).to eq(201)
    end

    it "validates URL before making request" do
      allow(Resolv).to receive(:getaddresses).with("internal.local")
                                             .and_return(["192.168.1.1"])

      expect { instance.post("http://internal.local/admin") }
        .to raise_error(ArgumentError, %r{Private/internal IP})
    end

    context "with json body" do
      it "sets Content-Type to application/json" do
        instance.post("https://api.example.com", json: { name: "test" })

        expect(mock_request.headers["Content-Type"]).to eq("application/json")
      end

      it "serializes body as JSON" do
        instance.post("https://api.example.com", json: { name: "test" })

        expect(JSON.parse(mock_request.body)).to eq({ "name" => "test" })
      end
    end

    context "with form body" do
      it "sets Content-Type to form-urlencoded" do
        instance.post("https://api.example.com", form: { name: "test" })

        expect(mock_request.headers["Content-Type"]).to eq("application/x-www-form-urlencoded")
      end

      it "encodes body as form data" do
        instance.post("https://api.example.com", form: { name: "test", value: "123" })

        expect(mock_request.body).to include("name=test")
        expect(mock_request.body).to include("value=123")
      end
    end

    context "with raw body" do
      it "sets body directly" do
        instance.post("https://api.example.com", body: "raw content")

        expect(mock_request.body).to eq("raw content")
      end
    end
  end
end
