require "webmock/rspec"

RSpec.describe Smolagents::DuckDuckGoSearchTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { query: "test search" } }
  let(:required_input_name) { :query }

  before do
    stub_request(:post, "https://lite.duckduckgo.com/lite/")
      .to_return(
        status: 200,
        body: <<~HTML
          <html>
          <body>
          <table>
            <tr>
              <td><a class="result-link">Example Site<span class="link-text">example.com/page</span></a></td>
              <td class="result-snippet">This is the description of the result.</td>
            </tr>
          </table>
          </body>
          </html>
        HTML
      )
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("duckduckgo_search")
    end

    it "has a description with temporal guidance" do
      expect(described_class.description).to include("current events")
      expect(described_class.description).to include("real-time information")
    end

    it "uses the lite endpoint" do
      expect(described_class.search_config.endpoint_url).to eq("https://lite.duckduckgo.com/lite/")
    end

    it "uses POST method" do
      expect(described_class.search_config.request_method).to eq(:post)
    end

    it "has rate limiting" do
      expect(described_class.included_modules).to include(Smolagents::Concerns::RateLimiter)
    end
  end

  describe "#call" do
    context "when search succeeds" do
      before do
        stub_request(:post, "https://lite.duckduckgo.com/lite/")
          .to_return(
            status: 200,
            body: <<~HTML
              <html>
              <body>
              <table>
                <tr>
                  <td><a class="result-link">Example Site<span class="link-text">example.com/page</span></a></td>
                  <td class="result-snippet">This is the description of the result.</td>
                </tr>
                <tr>
                  <td><a class="result-link">Another Site<span class="link-text">another.com</span></a></td>
                  <td class="result-snippet">Another description here.</td>
                </tr>
              </table>
              </body>
              </html>
            HTML
          )
      end

      it "returns search results" do
        result = tool.call(query: "test search")

        expect(result.to_s).to include("Example Site")
        expect(result.to_s).to include("example.com")
      end
    end

    context "when rate limited with 202" do
      before do
        stub_request(:post, "https://lite.duckduckgo.com/lite/")
          .to_return(status: 202, body: "Please slow down")
      end

      it "raises RateLimitError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::RateLimitError) do |error|
            expect(error.status_code).to eq(202)
          end
      end
    end

    context "when rate limited with 429" do
      before do
        stub_request(:post, "https://lite.duckduckgo.com/lite/")
          .to_return(status: 429, body: "Too many requests")
      end

      it "raises RateLimitError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::RateLimitError)
      end
    end

    context "when service unavailable" do
      before do
        stub_request(:post, "https://lite.duckduckgo.com/lite/")
          .to_return(status: 503, body: "Service unavailable")
      end

      it "raises ServiceUnavailableError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::ServiceUnavailableError)
      end
    end

    context "when HTTP error" do
      before do
        stub_request(:post, "https://lite.duckduckgo.com/lite/")
          .to_return(status: 500, body: "Internal error")
      end

      it "raises HttpError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::HttpError)
      end
    end

    context "when timeout" do
      before do
        stub_request(:post, "https://lite.duckduckgo.com/lite/")
          .to_timeout
      end

      it "raises Faraday error" do
        expect { tool.call(query: "test") }
          .to raise_error(Faraday::Error)
      end
    end
  end

  describe "max_results" do
    let(:tool) { described_class.new(max_results: 2) }

    before do
      stub_request(:post, "https://lite.duckduckgo.com/lite/")
        .to_return(
          status: 200,
          body: <<~HTML
            <html>
            <body>
            <table>
              <tr><td><a class="result-link">Result 1</a></td><td class="result-snippet">Desc 1</td></tr>
              <tr><td><a class="result-link">Result 2</a></td><td class="result-snippet">Desc 2</td></tr>
              <tr><td><a class="result-link">Result 3</a></td><td class="result-snippet">Desc 3</td></tr>
              <tr><td><a class="result-link">Result 4</a></td><td class="result-snippet">Desc 4</td></tr>
            </table>
            </body>
            </html>
          HTML
        )
    end

    it "limits results to max_results" do
      result = tool.call(query: "test")

      expect(result.to_s).to include("Result 1")
      expect(result.to_s).to include("Result 2")
      expect(result.to_s).not_to include("Result 3")
    end
  end
end
