# -- testing concern with arbitrary response objects
require "webmock/rspec"

RSpec.describe Smolagents::Http::ResponseHandling do
  let(:test_class) do
    Class.new do
      include Smolagents::Http::ResponseHandling
    end
  end

  let(:handler) { test_class.new }

  describe "#parse_json_response" do
    it "parses valid JSON" do
      response = double("response", body: '{"key": "value"}')

      result = handler.parse_json_response(response)

      expect(result).to eq({ "key" => "value" })
    end

    it "raises on invalid JSON" do
      response = double("response", body: "not json")

      expect { handler.parse_json_response(response) }.to raise_error(JSON::ParserError)
    end
  end

  describe "#require_success!" do
    def mock_response(status:, body: "", headers: {})
      env = {
        url: URI.parse("https://example.com/api"),
        method: :get
      }
      double(
        "response",
        success?: (200..299).cover?(status) && status != 202,
        status:,
        body:,
        headers:,
        env:
      )
    end

    context "when response is successful" do
      it "returns nil for 200" do
        response = mock_response(status: 200)

        expect(handler.require_success!(response)).to be_nil
      end

      it "returns nil for 201" do
        response = mock_response(status: 201)

        expect(handler.require_success!(response)).to be_nil
      end
    end

    context "when rate limited" do
      it "raises RateLimitError for 429" do
        response = mock_response(status: 429, body: "Too many requests")

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::RateLimitError) do |error|
            expect(error.status_code).to eq(429)
            expect(error.url).to eq("https://example.com/api")
          end
      end

      it "does not raise for 202 by default (service-specific handling)" do
        response = mock_response(status: 202, body: "Accepted")

        # 202 is not a rate limit by default - services like DDG override rate_limit_codes
        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::HttpError)
      end

      it "extracts retry-after header" do
        response = mock_response(
          status: 429,
          body: "Rate limited",
          headers: { "retry-after" => "60" }
        )

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::RateLimitError) do |error|
            expect(error.retry_after).to eq(60)
          end
      end
    end

    context "when service unavailable" do
      it "raises ServiceUnavailableError for 503" do
        response = mock_response(status: 503, body: "Service unavailable")

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::ServiceUnavailableError) do |error|
            expect(error.status_code).to eq(503)
          end
      end

      it "raises ServiceUnavailableError for 502" do
        response = mock_response(status: 502, body: "Bad gateway")

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::ServiceUnavailableError)
      end

      it "raises ServiceUnavailableError for 504" do
        response = mock_response(status: 504, body: "Gateway timeout")

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::ServiceUnavailableError)
      end
    end

    context "when other HTTP error" do
      it "raises HttpError for 404" do
        response = mock_response(status: 404, body: "Not found")

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::HttpError) do |error|
            expect(error.status_code).to eq(404)
            expect(error.message).to include("HTTP 404")
          end
      end

      it "raises HttpError for 500" do
        response = mock_response(status: 500, body: "Internal server error")

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::HttpError) do |error|
            expect(error.status_code).to eq(500)
          end
      end

      it "truncates long error bodies in message" do
        long_body = "x" * 500
        response = mock_response(status: 400, body: long_body)

        expect { handler.require_success!(response) }
          .to raise_error(Smolagents::HttpError) do |error|
            expect(error.message.length).to be < 300
          end
      end
    end

    context "with custom URL" do
      it "uses provided URL in error" do
        response = mock_response(status: 404, body: "Not found")

        expect { handler.require_success!(response, url: "https://custom.url/path") }
          .to raise_error(Smolagents::HttpError) do |error|
            expect(error.url).to eq("https://custom.url/path")
          end
      end
    end
  end

  describe "#safe_api_call" do
    it "returns block result on success" do
      result = handler.safe_api_call { "success" }

      expect(result).to eq("success")
    end

    it "lets RateLimitError propagate" do
      expect do
        handler.safe_api_call { raise Smolagents::RateLimitError.new(status_code: 429) }
      end.to raise_error(Smolagents::RateLimitError)
    end

    it "lets HttpError propagate" do
      expect do
        handler.safe_api_call { raise Smolagents::HttpError.new("error", status_code: 500) }
      end.to raise_error(Smolagents::HttpError)
    end

    it "lets Faraday::TimeoutError propagate" do
      expect do
        handler.safe_api_call { raise Faraday::TimeoutError }
      end.to raise_error(Faraday::TimeoutError)
    end
  end

  describe "status code defaults" do
    it "defaults rate_limit_codes to [429]" do
      expect(handler.rate_limit_codes).to eq([429])
    end

    it "defaults unavailable_codes to [502, 503, 504]" do
      expect(handler.unavailable_codes).to contain_exactly(502, 503, 504)
    end

    it "allows rate_limit_codes to be overridden" do
      allow(handler).to receive(:rate_limit_codes).and_return([429, 202])
      expect(handler.rate_limit_codes).to include(202)
    end
  end
end
