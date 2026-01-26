require "webmock/rspec"

RSpec.describe Smolagents::GoogleSearchTool do
  let(:api_key) { "test_google_api_key" }
  let(:cse_id) { "test_cse_id" }
  let(:tool) { described_class.new(api_key:, cse_id:) }
  let(:valid_args) { { query: "ruby programming" } }
  let(:required_input_name) { :query }

  let(:sample_json_response) do
    {
      "items" => [
        {
          "title" => "Ruby Language",
          "link" => "https://www.ruby-lang.org",
          "snippet" => "An object-oriented programming language."
        },
        {
          "title" => "Ruby on Rails",
          "link" => "https://rubyonrails.org",
          "snippet" => "A web application framework written in Ruby."
        }
      ]
    }
  end

  before do
    stub_request(:get, "https://www.googleapis.com/customsearch/v1")
      .with(query: hash_including(
        q: "ruby programming",
        key: api_key,
        cx: cse_id
      ))
      .to_return(status: 200, body: sample_json_response.to_json)
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("google_search")
    end

    it "has a description mentioning Google" do
      expect(described_class.description).to include("Google")
    end

    it "parses JSON responses" do
      expect(described_class.search_config.parser_type).to eq(:json)
    end

    it "requires GOOGLE_API_KEY" do
      expect(described_class.search_config.api_key_env).to eq("GOOGLE_API_KEY")
    end

    it "requires GOOGLE_CSE_ID" do
      config = described_class.search_config
      expect(config.required_params).to have_key(:cse_id)
    end

    it "has max results limit of 10" do
      expect(described_class.search_config.max_results_cap).to eq(10)
    end

    it "uses 'items' path for results" do
      expect(described_class.search_config.results_path_keys).to eq(["items"])
    end
  end

  describe "#call" do
    context "when search succeeds" do
      it "returns formatted results" do
        result = tool.call(query: "ruby programming")

        expect(result.to_s).to include("Ruby Language")
        expect(result.to_s).to include("https://www.ruby-lang.org")
      end

      it "includes snippets as descriptions" do
        result = tool.call(query: "ruby programming")

        expect(result.to_s).to include("object-oriented programming")
      end

      it "returns ToolResult" do
        result = tool.call(query: "ruby programming")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.tool_name).to eq("google_search")
      end
    end

    context "when required credentials missing" do
      it "raises error when GOOGLE_API_KEY not set" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GOOGLE_API_KEY").and_return(nil)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("GOOGLE_API_KEY", nil).and_return(nil)

        expect { described_class.new(cse_id:) }
          .to raise_error(ArgumentError, /Missing API key/)
      end

      it "raises error when GOOGLE_CSE_ID not set" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GOOGLE_CSE_ID").and_return(nil)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("GOOGLE_CSE_ID", nil).and_return(nil)

        expect { described_class.new(api_key:) }
          .to raise_error(Smolagents::ToolConfigurationError)
      end
    end

    context "when no results" do
      before do
        stub_request(:get, "https://www.googleapis.com/customsearch/v1")
          .with(query: hash_including(
            q: "xyznonexistent999999",
            key: api_key,
            cx: cse_id
          ))
          .to_return(status: 200, body: { "items" => [] }.to_json)
      end

      it "returns empty result" do
        result = tool.call(query: "xyznonexistent999999")

        expect(result.data).to be_empty
      end
    end

    context "when HTTP error" do
      before do
        stub_request(:get, "https://www.googleapis.com/customsearch/v1")
          .with(query: hash_including(
            q: "error_test",
            key: api_key,
            cx: cse_id
          ))
          .to_return(status: 403, body: "Forbidden")
      end

      it "raises ApiError" do
        expect { tool.call(query: "error_test") }
          .to raise_error(Smolagents::ApiError)
      end
    end
  end

  describe "JSON parsing" do
    context "with multiple results" do
      before do
        stub_request(:get, "https://www.googleapis.com/customsearch/v1")
          .with(query: hash_including(
            q: "test",
            key: api_key,
            cx: cse_id
          ))
          .to_return(status: 200, body: {
            "items" => [
              { "title" => "Result 1", "link" => "http://one.com", "snippet" => "Snippet 1" },
              { "title" => "Result 2", "link" => "http://two.com", "snippet" => "Snippet 2" },
              { "title" => "Result 3", "link" => "http://three.com", "snippet" => "Snippet 3" }
            ]
          }.to_json)
      end

      it "parses all results" do
        result = tool.call(query: "test")

        expect(result.data.size).to eq(3)
        expect(result.data[0][:title]).to eq("Result 1")
        expect(result.data[0][:link]).to eq("http://one.com")
        expect(result.data[0][:description]).to eq("Snippet 1")
      end
    end

    context "with missing snippet" do
      before do
        stub_request(:get, "https://www.googleapis.com/customsearch/v1")
          .with(query: hash_including(
            q: "incomplete",
            key: api_key,
            cx: cse_id
          ))
          .to_return(status: 200, body: {
            "items" => [
              { "title" => "No Snippet", "link" => "http://example.com" }
            ]
          }.to_json)
      end

      it "handles missing snippet" do
        result = tool.call(query: "incomplete")

        expect(result.data[0][:title]).to eq("No Snippet")
        expect(result.data[0][:link]).to eq("http://example.com")
      end
    end
  end

  describe "max_results parameter" do
    let(:tool_with_limit) { described_class.new(api_key:, cse_id:, max_results: 5) }

    before do
      stub_request(:get, "https://www.googleapis.com/customsearch/v1")
        .with(query: hash_including(
          q: "max_results_test",
          key: api_key,
          cx: cse_id,
          num: "5"
        ))
        .to_return(status: 200, body: {
          "items" => Array.new(5) do |i|
            { "title" => "Result #{i + 1}", "link" => "http://example.com/#{i + 1}", "snippet" => "Snippet" }
          end
        }.to_json)
    end

    it "limits results with max_results parameter" do
      result = tool_with_limit.call(query: "max_results_test")

      expect(result.data.size).to eq(5)
    end
  end

  describe "field mapping" do
    before do
      stub_request(:get, "https://www.googleapis.com/customsearch/v1")
        .with(query: hash_including(
          q: "mapping_test",
          key: api_key,
          cx: cse_id
        ))
        .to_return(status: 200, body: {
          "items" => [
            {
              "title" => "Mapped Title",
              "link" => "http://mapped.com",
              "snippet" => "Mapped Snippet"
            }
          ]
        }.to_json)
    end

    it "maps fields correctly from API response" do
      result = tool.call(query: "mapping_test")

      expect(result.data[0]).to include(:title, :link, :description)
      expect(result.data[0][:title]).to eq("Mapped Title")
      expect(result.data[0][:link]).to eq("http://mapped.com")
      expect(result.data[0][:description]).to eq("Mapped Snippet")
    end
  end
end
