# Unit tests for HTTP connection building and caching.

RSpec.describe Smolagents::Http::Connection do
  let(:test_class) do
    Class.new do
      include Smolagents::Http::Connection

      attr_accessor :timeout

      def initialize
        @timeout = nil
        @user_agent = nil
      end

      # Expose private methods for testing
      def test_connection(...) = connection(...)
      def test_build_connection(...) = build_connection(...)
      def test_close_connections = close_connections
      def test_user_agent_string = user_agent_string
    end
  end

  let(:instance) { test_class.new }

  describe "#connection" do
    it "builds a Faraday connection" do
      conn = instance.test_connection("https://example.com")

      expect(conn).to be_a(Faraday::Connection)
    end

    it "caches connections by URL" do
      conn1 = instance.test_connection("https://example.com")
      conn2 = instance.test_connection("https://example.com")

      expect(conn1).to equal(conn2)
    end

    it "creates separate connections for different URLs" do
      conn1 = instance.test_connection("https://example.com")
      conn2 = instance.test_connection("https://other.com")

      expect(conn1).not_to equal(conn2)
    end

    it "creates separate connections for different resolved IPs" do
      conn1 = instance.test_connection("https://example.com", resolved_ip: "1.2.3.4")
      conn2 = instance.test_connection("https://example.com", resolved_ip: "5.6.7.8")

      expect(conn1).not_to equal(conn2)
    end

    it "creates separate connections for different timeouts" do
      conn1 = instance.test_connection("https://example.com", timeout: 10)
      conn2 = instance.test_connection("https://example.com", timeout: 30)

      expect(conn1).not_to equal(conn2)
    end
  end

  describe "#build_connection" do
    it "sets default Accept header" do
      conn = instance.test_build_connection("https://example.com")

      expect(conn.headers["Accept"]).to eq("*/*")
    end

    it "sets Accept-Language header" do
      conn = instance.test_build_connection("https://example.com")

      expect(conn.headers["Accept-Language"]).to eq("en-US,en;q=0.5")
    end

    it "sets Connection keep-alive header" do
      conn = instance.test_build_connection("https://example.com")

      expect(conn.headers["Connection"]).to eq("keep-alive")
    end

    it "sets User-Agent header" do
      conn = instance.test_build_connection("https://example.com")

      expect(conn.headers["User-Agent"]).to include("smolagents")
    end

    it "sets timeout from parameter" do
      conn = instance.test_build_connection("https://example.com", timeout: 60)

      expect(conn.options.timeout).to eq(60)
    end

    context "with DnsRebindingGuard middleware" do
      it "includes middleware when resolved_ip provided" do
        conn = instance.test_build_connection("https://example.com", resolved_ip: "1.2.3.4")
        middleware_classes = conn.builder.handlers.map do |h|
          h.klass
        rescue StandardError
          h
        end

        expect(middleware_classes).to include(Smolagents::Http::DnsRebindingGuard)
      end

      it "skips middleware when allow_private is true" do
        conn = instance.test_build_connection("https://example.com", allow_private: true)
        middleware_classes = conn.builder.handlers.map do |h|
          h.klass
        rescue StandardError
          h
        end

        expect(middleware_classes).not_to include(Smolagents::Http::DnsRebindingGuard)
      end
    end
  end

  describe "#close_connections" do
    it "clears the connection cache without raising" do
      instance.test_connection("https://example.com")

      expect { instance.test_close_connections }.not_to raise_error
    end

    it "handles being called when no connections exist" do
      expect { instance.test_close_connections }.not_to raise_error
    end
  end

  describe "#user_agent_string" do
    it "returns default user agent when not set" do
      result = instance.test_user_agent_string

      expect(result).to include("smolagents")
    end

    it "returns string when user_agent is a String" do
      instance.user_agent = "CustomAgent/1.0"
      result = instance.test_user_agent_string

      expect(result).to eq("CustomAgent/1.0")
    end

    it "converts UserAgent object to string" do
      instance.user_agent = Smolagents::Http::UserAgent.new(agent_version: "1.0.0")
      result = instance.test_user_agent_string

      expect(result).to include("Smolagents")
    end
  end
end
