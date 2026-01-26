require "webmock/rspec"

RSpec.describe Smolagents::SearxngSearchTool do
  let(:instance_url) { "https://searxng.example.com" }
  let(:tool) { described_class.new(instance_url:) }
  let(:valid_args) { { query: "test search" } }
  let(:required_input_name) { :query }

  before do
    stub_request(:get, "#{instance_url}/search")
      .with(query: hash_including(q: "test search", format: "json"))
      .to_return(
        status: 200,
        body: { results: [{ title: "Example", url: "https://example.com", content: "Description" }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("searxng_search")
    end

    it "has a description mentioning metasearch" do
      expect(described_class.description).to include("metasearch")
    end

    it "requires instance_url" do
      expect { described_class.new }.to raise_error(Smolagents::ToolConfigurationError, /instance_url/)
    end

    it "accepts instance_url from ENV" do
      original = ENV.fetch("SEARXNG_URL", nil)
      ENV["SEARXNG_URL"] = instance_url
      begin
        tool = described_class.new
        expect(tool.instance_url).to eq(instance_url)
      ensure
        original ? ENV["SEARXNG_URL"] = original : ENV.delete("SEARXNG_URL")
      end
    end

    it "parses JSON responses" do
      expect(described_class.search_config.parser_type).to eq(:json)
    end
  end

  describe "#call" do
    context "when search succeeds" do
      before do
        stub_request(:get, "#{instance_url}/search")
          .with(query: hash_including(q: "ruby programming", format: "json"))
          .to_return(
            status: 200,
            body: {
              results: [
                { title: "Ruby Lang", url: "https://ruby-lang.org", content: "Official Ruby site" },
                { title: "Ruby Docs", url: "https://docs.ruby-lang.org", content: "Documentation" }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns search results" do
        result = tool.call(query: "ruby programming")

        expect(result.to_s).to include("Ruby Lang")
        expect(result.to_s).to include("ruby-lang.org")
      end

      it "includes descriptions" do
        result = tool.call(query: "ruby programming")

        expect(result.to_s).to include("Official Ruby site")
      end
    end

    context "when no results" do
      before do
        stub_request(:get, "#{instance_url}/search")
          .with(query: hash_including(q: "xyznonexistent123"))
          .to_return(
            status: 200,
            body: { results: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns empty result" do
        result = tool.call(query: "xyznonexistent123")

        # Empty results return a minimal string
        expect(result.data).to be_empty
      end
    end

    context "when HTTP error" do
      before do
        stub_request(:get, "#{instance_url}/search")
          .with(query: hash_including(format: "json"))
          .to_return(status: 500, body: "Internal error")
      end

      it "raises HttpError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::HttpError)
      end
    end

    context "when timeout" do
      before do
        stub_request(:get, "#{instance_url}/search")
          .with(query: hash_including(format: "json"))
          .to_timeout
      end

      it "raises Faraday error" do
        expect { tool.call(query: "test") }
          .to raise_error(Faraday::Error)
      end
    end
  end

  describe "categories" do
    let(:tool) { described_class.new(instance_url:, categories: "images") }

    before do
      stub_request(:get, "#{instance_url}/search")
        .with(query: hash_including(categories: "images"))
        .to_return(
          status: 200,
          body: { results: [{ title: "Image Result", url: "https://img.example.com", content: "An image" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "includes categories in request" do
      tool.call(query: "test")

      expect(WebMock).to have_requested(:get, "#{instance_url}/search")
        .with(query: hash_including(categories: "images"))
    end
  end

  describe "instance URL normalization" do
    it "strips trailing slash from instance_url" do
      tool_with_slash = described_class.new(instance_url: "#{instance_url}/")

      stub_request(:get, "#{instance_url}/search")
        .with(query: hash_including(format: "json"))
        .to_return(
          status: 200,
          body: { results: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      tool_with_slash.call(query: "test")

      # Verifies trailing slash was stripped - no double slash in URL
      expect(WebMock).to have_requested(:get, "#{instance_url}/search")
        .with(query: hash_including(format: "json"))
    end
  end
end
