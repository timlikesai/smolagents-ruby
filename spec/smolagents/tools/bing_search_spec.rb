require "webmock/rspec"

RSpec.describe Smolagents::BingSearchTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { query: "ruby programming" } }
  let(:required_input_name) { :query }

  let(:sample_rss_response) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Bing Search</title>
          <item>
            <title>Ruby Language Official Site</title>
            <link>https://www.ruby-lang.org</link>
            <description>The official website for the Ruby programming language.</description>
          </item>
          <item>
            <title>Ruby on Rails</title>
            <link>https://rubyonrails.org</link>
            <description>A web application framework written in Ruby.</description>
          </item>
        </channel>
      </rss>
    XML
  end

  before do
    stub_request(:get, "https://www.bing.com/search")
      .with(query: hash_including(q: "ruby programming", format: "rss"))
      .to_return(status: 200, body: sample_rss_response)
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("bing_search")
    end

    it "has a description mentioning Bing" do
      expect(described_class.description).to include("Bing")
    end

    it "parses RSS responses" do
      expect(described_class.search_config.parser_type).to eq(:rss)
    end

    it "includes format=rss parameter" do
      expect(described_class.search_config.additional_params_config).to include(format: "rss")
    end

    it "does not require API key" do
      expect(described_class.search_config.api_key_env).to be_nil
    end
  end

  describe "#call" do
    context "when search succeeds" do
      it "returns formatted results" do
        result = tool.call(query: "ruby programming")

        expect(result.to_s).to include("Ruby Language Official Site")
        expect(result.to_s).to include("https://www.ruby-lang.org")
      end

      it "includes descriptions" do
        result = tool.call(query: "ruby programming")

        expect(result.to_s).to include("official website")
      end

      it "returns ToolResult" do
        result = tool.call(query: "ruby programming")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.tool_name).to eq("bing_search")
      end
    end

    context "when no results" do
      before do
        stub_request(:get, "https://www.bing.com/search")
          .with(query: hash_including(q: "xyznonexistent12345"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <title>Bing Search</title>
              </channel>
            </rss>
          XML
      end

      it "returns empty result" do
        result = tool.call(query: "xyznonexistent12345")

        expect(result.data).to be_empty
      end
    end

    context "when HTTP error" do
      before do
        stub_request(:get, "https://www.bing.com/search")
          .with(query: hash_including(q: "error_test"))
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises HttpError" do
        expect { tool.call(query: "error_test") }
          .to raise_error(Smolagents::HttpError)
      end
    end
  end

  describe "RSS parsing" do
    context "with multiple results" do
      before do
        stub_request(:get, "https://www.bing.com/search")
          .with(query: hash_including(q: "test"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <item>
                  <title>Result 1</title>
                  <link>http://example.com/1</link>
                  <description>Description 1</description>
                </item>
                <item>
                  <title>Result 2</title>
                  <link>http://example.com/2</link>
                  <description>Description 2</description>
                </item>
                <item>
                  <title>Result 3</title>
                  <link>http://example.com/3</link>
                  <description>Description 3</description>
                </item>
              </channel>
            </rss>
          XML
      end

      it "parses all results" do
        result = tool.call(query: "test")

        expect(result.data.size).to eq(3)
        expect(result.data[0][:title]).to eq("Result 1")
        expect(result.data[1][:title]).to eq("Result 2")
        expect(result.data[2][:title]).to eq("Result 3")
      end
    end

    context "with missing description" do
      before do
        stub_request(:get, "https://www.bing.com/search")
          .with(query: hash_including(q: "incomplete"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <item>
                  <title>No Description</title>
                  <link>http://example.com</link>
                </item>
              </channel>
            </rss>
          XML
      end

      it "handles missing description" do
        result = tool.call(query: "incomplete")

        expect(result.data[0][:title]).to eq("No Description")
        expect(result.data[0][:link]).to eq("http://example.com")
      end
    end

    context "with special characters" do
      before do
        stub_request(:get, "https://www.bing.com/search")
          .with(query: hash_including(q: "special"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <item>
                  <title>Test &amp; Ruby &lt;Framework&gt;</title>
                  <link>http://example.com</link>
                  <description>Rock &amp; Roll Programming &quot;Guide&quot;</description>
                </item>
              </channel>
            </rss>
          XML
      end

      it "handles HTML entities" do
        result = tool.call(query: "special")

        expect(result.data[0][:title]).to include("&")
        expect(result.data[0][:description]).to include("&")
      end
    end
  end
end
