require "spec_helper"

RSpec.describe Smolagents::Concerns::Support::BrowserMode do
  subject(:browser) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Support::BrowserMode
    end
  end

  describe "#browser_headers" do
    it "returns a Hash" do
      headers = browser.browser_headers
      expect(headers).to be_a(Hash)
    end

    it "includes User-Agent header" do
      headers = browser.browser_headers
      expect(headers).to have_key("User-Agent")
    end

    it "includes Accept header" do
      headers = browser.browser_headers
      expect(headers).to have_key("Accept")
    end

    it "includes Accept-Language header" do
      headers = browser.browser_headers
      expect(headers).to have_key("Accept-Language")
    end

    it "returns frozen hash" do
      headers = browser.browser_headers
      expect(headers).to be_frozen
    end

    it "has realistic User-Agent" do
      headers = browser.browser_headers
      ua = headers["User-Agent"]

      expect(ua).to include("Mozilla")
      expect(ua).to include("Chrome")
      expect(ua).to include("Safari")
    end

    it "has realistic Accept header" do
      headers = browser.browser_headers
      accept = headers["Accept"]

      expect(accept).to include("text/html")
      expect(accept).to include("application/xhtml+xml")
    end

    it "has en-US language preference" do
      headers = browser.browser_headers
      lang = headers["Accept-Language"]

      expect(lang).to include("en-US")
    end

    it "returns same headers each time" do
      headers1 = browser.browser_headers
      headers2 = browser.browser_headers

      expect(headers1).to eq(headers2)
    end
  end

  describe "#browser_type" do
    it "returns :chrome symbol" do
      expect(browser.browser_type).to eq(:chrome)
    end

    it "is consistent" do
      type1 = browser.browser_type
      type2 = browser.browser_type

      expect(type1).to eq(type2)
    end
  end

  describe "#headless?" do
    it "returns true" do
      expect(browser.headless?).to be true
    end

    it "is consistent" do
      expect(browser.headless?).to be true
      expect(browser.headless?).to be true
    end
  end

  describe "integration" do
    it "can be used as HTTP request headers" do
      headers = browser.browser_headers

      expect(headers["User-Agent"]).to be_a(String)
      expect(headers["Accept"]).to be_a(String)
      expect(headers["Accept-Language"]).to be_a(String)
    end

    it "provides complete headers for HTTP requests" do
      headers = browser.browser_headers

      expect(headers.size).to be >= 3
      headers.each_value { |value| expect(value).to be_a(String) }
    end
  end

  describe "constants" do
    it "defines USER_AGENT constant" do
      ua = Smolagents::Concerns::Support::BrowserMode::USER_AGENT
      expect(ua).to be_a(String)
      expect(ua).to include("Mozilla")
    end

    it "defines ACCEPT constant" do
      accept = Smolagents::Concerns::Support::BrowserMode::ACCEPT
      expect(accept).to be_a(String)
      expect(accept).to include("text/html")
    end

    it "defines ACCEPT_LANGUAGE constant" do
      lang = Smolagents::Concerns::Support::BrowserMode::ACCEPT_LANGUAGE
      expect(lang).to be_a(String)
      expect(lang).to include("en-US")
    end

    it "USER_AGENT constant is frozen" do
      ua = Smolagents::Concerns::Support::BrowserMode::USER_AGENT
      expect(ua).to be_frozen
    end

    it "ACCEPT constant is frozen" do
      accept = Smolagents::Concerns::Support::BrowserMode::ACCEPT
      expect(accept).to be_frozen
    end

    it "ACCEPT_LANGUAGE constant is frozen" do
      lang = Smolagents::Concerns::Support::BrowserMode::ACCEPT_LANGUAGE
      expect(lang).to be_frozen
    end
  end

  describe "usage examples" do
    it "works with mock HTTP client" do
      class MockHttpClient
        include Smolagents::Concerns::Support::BrowserMode

        def get(url, headers: {})
          "Got #{url} with #{headers["User-Agent"]}"
        end
      end

      client = MockHttpClient.new
      result = client.get("http://example.com", headers: client.browser_headers)

      expect(result).to include("Got http://example.com")
      expect(result).to include("Mozilla")
    end

    it "can override headers while preserving browser mode" do
      headers = browser.browser_headers.merge("Authorization" => "Bearer token")

      expect(headers["User-Agent"]).to include("Mozilla")
      expect(headers["Authorization"]).to eq("Bearer token")
    end
  end
end
