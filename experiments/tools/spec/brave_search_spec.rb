require "webmock/rspec"

RSpec.describe Smolagents::BraveSearchTool do
  let(:api_key) { "test_brave_api_key" }
  let(:tool) { described_class.new(api_key:) }
  let(:valid_args) { { query: "ruby gems" } }
  let(:required_input_name) { :query }

  let(:sample_json_response) do
    {
      "web" => {
        "results" => [
          {
            "title" => "Rubygems.org",
            "url" => "https://rubygems.org",
            "description" => "The Ruby community's gem hosting service."
          },
          {
            "title" => "Bundler Documentation",
            "url" => "https://bundler.io",
            "description" => "The best way to manage a Ruby application's dependencies."
          }
        ]
      }
    }
  end

  before do
    stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
      .with(
        query: hash_including(q: "ruby gems"),
        headers: { "X-Subscription-Token" => api_key }
      )
      .to_return(status: 200, body: sample_json_response.to_json)
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("brave_search")
    end

    it "has a description mentioning privacy" do
      expect(described_class.description).to include("privacy")
    end

    it "parses JSON responses" do
      expect(described_class.search_config.parser_type).to eq(:json)
    end

    it "requires BRAVE_API_KEY" do
      expect(described_class.search_config.api_key_env).to eq("BRAVE_API_KEY")
    end

    it "uses X-Subscription-Token header" do
      expect(described_class.search_config.auth_header_config[:name]).to eq("X-Subscription-Token")
    end

    it "has rate limit of 1.0" do
      expect(described_class.search_config.rate_limit_interval).to eq(1.0)
    end
  end

  describe "#call" do
    context "when search succeeds" do
      it "returns formatted results" do
        result = tool.call(query: "ruby gems")

        expect(result.to_s).to include("Rubygems.org")
        expect(result.to_s).to include("https://rubygems.org")
      end

      it "includes descriptions" do
        result = tool.call(query: "ruby gems")

        expect(result.to_s).to include("gem hosting service")
      end

      it "returns ToolResult" do
        result = tool.call(query: "ruby gems")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.tool_name).to eq("brave_search")
      end
    end

    context "when API key missing" do
      it "raises error when BRAVE_API_KEY env var not set" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("BRAVE_API_KEY").and_return(nil)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("BRAVE_API_KEY", nil).and_return(nil)

        expect { described_class.new }
          .to raise_error(ArgumentError, /Missing API key/)
      end
    end

    context "when no results" do
      before do
        stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
          .with(
            query: hash_including(q: "xyznonexistent99999"),
            headers: { "X-Subscription-Token" => api_key }
          )
          .to_return(status: 200, body: { "web" => { "results" => [] } }.to_json)
      end

      it "returns empty result" do
        result = tool.call(query: "xyznonexistent99999")

        expect(result.data).to be_empty
      end
    end

    context "when HTTP error" do
      before do
        stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
          .with(
            query: hash_including(q: "error_test"),
            headers: { "X-Subscription-Token" => api_key }
          )
          .to_return(status: 401, body: "Unauthorized")
      end

      it "raises ApiError for auth failure" do
        expect { tool.call(query: "error_test") }
          .to raise_error(Smolagents::ApiError)
      end
    end
  end

  describe "JSON parsing" do
    context "with multiple results" do
      before do
        stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
          .with(
            query: hash_including(q: "test"),
            headers: { "X-Subscription-Token" => api_key }
          )
          .to_return(status: 200, body: {
            "web" => {
              "results" => [
                { "title" => "Result 1", "url" => "http://one.com", "description" => "Desc 1" },
                { "title" => "Result 2", "url" => "http://two.com", "description" => "Desc 2" },
                { "title" => "Result 3", "url" => "http://three.com", "description" => "Desc 3" }
              ]
            }
          }.to_json)
      end

      it "parses all results" do
        result = tool.call(query: "test")

        expect(result.data.size).to eq(3)
        expect(result.data[0][:title]).to eq("Result 1")
        expect(result.data[0][:link]).to eq("http://one.com")
      end
    end

    context "with missing description" do
      before do
        stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
          .with(
            query: hash_including(q: "incomplete"),
            headers: { "X-Subscription-Token" => api_key }
          )
          .to_return(status: 200, body: {
            "web" => {
              "results" => [
                { "title" => "No Desc", "url" => "http://example.com" }
              ]
            }
          }.to_json)
      end

      it "handles missing description" do
        result = tool.call(query: "incomplete")

        expect(result.data[0][:title]).to eq("No Desc")
        expect(result.data[0][:link]).to eq("http://example.com")
      end
    end
  end

  describe "field mapping" do
    before do
      stub_request(:get, "https://api.search.brave.com/res/v1/web/search")
        .with(
          query: hash_including(q: "mapping_test"),
          headers: { "X-Subscription-Token" => api_key }
        )
        .to_return(status: 200, body: {
          "web" => {
            "results" => [
              {
                "title" => "Mapped Title",
                "url" => "http://mapped.com",
                "description" => "Mapped Description"
              }
            ]
          }
        }.to_json)
    end

    it "maps fields correctly from API response" do
      result = tool.call(query: "mapping_test")

      expect(result.data[0]).to include(:title, :link, :description)
      expect(result.data[0][:title]).to eq("Mapped Title")
      expect(result.data[0][:link]).to eq("http://mapped.com")
      expect(result.data[0][:description]).to eq("Mapped Description")
    end
  end
end
