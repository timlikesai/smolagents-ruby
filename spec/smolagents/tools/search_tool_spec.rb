require "webmock/rspec"

RSpec.describe Smolagents::SearchTool do
  describe "DSL configuration" do
    let(:test_search_class) do
      Class.new(described_class) do
        configure do
          name "test_search"
          description "A test search tool"
          endpoint "https://api.test.com/search"
          parses :json
          results_path "data", "items"
          field_mapping title: "name", link: "url", description: "snippet"
        end
      end
    end

    it "sets the tool name" do
      expect(test_search_class.tool_name).to eq("test_search")
    end

    it "sets the description" do
      expect(test_search_class.description).to eq("A test search tool")
    end

    it "sets the inputs" do
      expect(test_search_class.inputs).to have_key(:query)
    end

    it "sets the output type" do
      expect(test_search_class.output_type).to eq("string")
    end
  end

  describe "JSON parser configuration" do
    let(:json_search_class) do
      Class.new(described_class) do
        configure do
          name "json_search"
          description "JSON search"
          endpoint "https://api.test.com/search"
          parses :json
          results_path "results"
          field_mapping title: "title", link: "link", description: "desc"
        end
      end
    end

    before do
      stub_request(:get, "https://api.test.com/search")
        .with(query: { q: "test query" })
        .to_return(
          status: 200,
          body: { results: [
            { title: "Result 1", link: "https://example.com/1", desc: "Description 1" },
            { title: "Result 2", link: "https://example.com/2", desc: "Description 2" }
          ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "fetches and formats results" do
      tool = json_search_class.new

      result = tool.call(query: "test query")

      expect(result.to_s).to include("Result 1")
      expect(result.to_s).to include("https://example.com/1")
      expect(result.to_s).to include("Description 1")
    end
  end

  describe "API key configuration" do
    let(:api_search_class) do
      Class.new(described_class) do
        configure do
          name "api_search"
          description "API search"
          endpoint "https://api.test.com/search"
          parses :json
          requires_api_key "TEST_API_KEY"
          auth_header "X-API-Key"
          results_path "data"
        end
      end
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TEST_API_KEY").and_return("secret-key")
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("TEST_API_KEY", nil).and_return("secret-key")

      stub_request(:get, "https://api.test.com/search")
        .with(
          query: { q: "test" },
          headers: { "X-API-Key" => "secret-key" }
        )
        .to_return(
          status: 200,
          body: { data: [{ title: "API Result", link: "https://api.com", description: "From API" }] }.to_json
        )
    end

    it "includes API key in headers" do
      tool = api_search_class.new

      result = tool.call(query: "test")

      expect(result.to_s).to include("API Result")
    end
  end

  describe "rate limiting configuration" do
    let(:rate_limited_class) do
      Class.new(described_class) do
        configure do
          name "rate_limited_search"
          description "Rate limited search"
          endpoint "https://api.test.com/search"
          parses :json
          rate_limit 1.0
          results_path "results"
        end
      end
    end

    it "includes RateLimiter concern" do
      expect(rate_limited_class.included_modules).to include(Smolagents::Concerns::RateLimiter)
    end
  end

  describe "max_results" do
    let(:search_class) do
      Class.new(described_class) do
        configure do
          name "limited_search"
          description "Limited search"
          endpoint "https://api.test.com/search"
          parses :json
          results_path "results"
        end
      end
    end

    before do
      results = (1..10).map { |i| { title: "Result #{i}", link: "https://example.com/#{i}", description: "Desc #{i}" } }
      stub_request(:get, "https://api.test.com/search")
        .with(query: { q: "test" })
        .to_return(status: 200, body: { results: results }.to_json)
    end

    it "limits results to max_results" do
      tool = search_class.new(max_results: 3)

      result = tool.call(query: "test")

      expect(result.to_s).to include("Result 1")
      expect(result.to_s).to include("Result 2")
      expect(result.to_s).to include("Result 3")
      expect(result.to_s).not_to include("Result 4")
    end
  end

  describe "custom fetch_results override" do
    let(:custom_search_class) do
      Class.new(described_class) do
        configure do
          name "custom_search"
          description "Custom search"
          endpoint "https://custom.test.com/search"
          parses :json
        end

        def fetch_results(query:)
          response = get(endpoint, params: { search: query })
          data = parse_json(response.body)
          data["custom_results"].map do |r|
            { title: r["name"], link: r["href"], description: r["text"] }
          end
        end
      end
    end

    before do
      stub_request(:get, "https://custom.test.com/search")
        .with(query: { search: "custom query" })
        .to_return(
          status: 200,
          body: { custom_results: [
            { name: "Custom 1", href: "https://custom.com/1", text: "Custom desc" }
          ] }.to_json
        )
    end

    it "uses custom fetch logic" do
      tool = custom_search_class.new

      result = tool.call(query: "custom query")

      expect(result.to_s).to include("Custom 1")
      expect(result.to_s).to include("https://custom.com/1")
    end
  end

  describe "nested results path" do
    let(:nested_search_class) do
      Class.new(described_class) do
        configure do
          name "nested_search"
          description "Nested results"
          endpoint "https://api.test.com/search"
          parses :json
          results_path "response", "data", "items"
        end
      end
    end

    before do
      stub_request(:get, "https://api.test.com/search")
        .with(query: { q: "nested" })
        .to_return(
          status: 200,
          body: {
            response: {
              data: {
                items: [{ title: "Nested Result", link: "https://nested.com", description: "Deep" }]
              }
            }
          }.to_json
        )
    end

    it "extracts from nested path" do
      tool = nested_search_class.new

      result = tool.call(query: "nested")

      expect(result.to_s).to include("Nested Result")
    end
  end
end
