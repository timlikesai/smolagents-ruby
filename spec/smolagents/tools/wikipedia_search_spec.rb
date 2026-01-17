require "webmock/rspec"

RSpec.describe Smolagents::WikipediaSearchTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { query: "Ruby programming" } }
  let(:required_input_name) { :query }

  before do
    stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
      .to_return(
        status: 200,
        body: {
          query: {
            pages: {
              "12345" => {
                pageid: 12_345,
                index: 1,
                title: "Ruby (programming language)",
                extract: "Ruby is a dynamic, interpreted programming language.",
                fullurl: "https://en.wikipedia.org/wiki/Ruby_(programming_language)"
              }
            }
          }
        }.to_json
      )
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("wikipedia")
    end

    it "has a description with temporal guidance" do
      expect(described_class.description).to include("established facts")
      expect(described_class.description).to include("may not have the most current")
    end

    it "accepts query input" do
      expect(described_class.inputs).to have_key(:query)
    end
  end

  describe "#call" do
    context "when articles are found" do
      before do
        stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
          .with(query: hash_including(
            action: "query",
            generator: "search",
            prop: "extracts|info"
          ))
          .to_return(
            status: 200,
            body: {
              query: {
                pages: {
                  "12345" => {
                    pageid: 12_345,
                    index: 1,
                    title: "The New York Times",
                    extract: "The New York Times is an American daily newspaper in New York City.",
                    fullurl: "https://en.wikipedia.org/wiki/The_New_York_Times"
                  }
                }
              }
            }.to_json
          )
      end

      it "returns article extract" do
        result = tool.call(query: "New York Times")

        expect(result.to_s).to include("The New York Times")
        expect(result.to_s).to include("American daily newspaper")
        expect(result.to_s).to include("en.wikipedia.org")
      end

      it "includes source link" do
        result = tool.call(query: "New York Times")

        expect(result.to_s).to include("Source:")
        expect(result.to_s).to include("The_New_York_Times")
      end
    end

    context "when no articles found" do
      before do
        stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
          .to_return(
            status: 200,
            body: { query: { pages: {} } }.to_json
          )
      end

      it "returns no results message" do
        result = tool.call(query: "Nonexistent Article XYZ123")

        expect(result.to_s).to include("No Wikipedia article found")
      end
    end

    context "with search-style queries" do
      before do
        stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
          .to_return(
            status: 200,
            body: {
              query: {
                pages: {
                  "12345" => {
                    pageid: 12_345,
                    index: 1,
                    title: "The New York Times",
                    extract: "The New York Times is headquartered at 620 Eighth Avenue.",
                    fullurl: "https://en.wikipedia.org/wiki/The_New_York_Times"
                  }
                }
              }
            }.to_json
          )
      end

      it "finds articles matching search terms" do
        result = tool.call(query: "New York Times address")

        expect(result.to_s).to include("The New York Times")
        expect(result.to_s).to include("620 Eighth Avenue")
      end
    end

    context "when rate limited" do
      before do
        stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
          .to_return(status: 429, body: "Rate limited")
      end

      it "raises RateLimitError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::RateLimitError)
      end
    end

    context "when service unavailable" do
      before do
        stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
          .to_return(status: 503, body: "Service unavailable")
      end

      it "raises ServiceUnavailableError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::ServiceUnavailableError)
      end
    end
  end

  describe "language support" do
    let(:tool) { described_class.new(language: "es") }

    before do
      stub_request(:get, %r{es\.wikipedia\.org/w/api\.php})
        .to_return(
          status: 200,
          body: {
            query: {
              pages: {
                "123" => {
                  pageid: 123,
                  index: 1,
                  title: "Ruby",
                  extract: "Ruby es un lenguaje de programacion.",
                  fullurl: "https://es.wikipedia.org/wiki/Ruby"
                }
              }
            }
          }.to_json
        )
    end

    it "queries the correct language Wikipedia" do
      result = tool.call(query: "Ruby")

      expect(result.to_s).to include("es.wikipedia.org")
    end
  end

  describe "max_results" do
    let(:tool) { described_class.new(max_results: 1) }

    before do
      stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
        .to_return(
          status: 200,
          body: {
            query: {
              pages: {
                "1" => { pageid: 1, index: 1, title: "Article 1", extract: "Content 1" },
                "2" => { pageid: 2, index: 2, title: "Article 2", extract: "Content 2" }
              }
            }
          }.to_json
        )
    end

    it "limits results" do
      result = tool.call(query: "test")

      expect(result.to_s).to include("Article")
      # Should only have one article section
      expect(result.to_s.scan(/^## /).count).to eq(1)
    end
  end

  describe "extract cleaning" do
    let(:tool) { described_class.new }

    before do
      stub_request(:get, %r{en\.wikipedia\.org/w/api\.php})
        .to_return(
          status: 200,
          body: {
            query: {
              pages: {
                "1" => {
                  pageid: 1,
                  index: 1,
                  title: "Test",
                  extract: "Content  with   excessive   whitespace\n\n\nand newlines"
                }
              }
            }
          }.to_json
        )
    end

    it "normalizes whitespace in extracts" do
      result = tool.call(query: "test")

      expect(result.to_s).not_to include("  ")
      expect(result.to_s).to include("Content with excessive whitespace and newlines")
    end
  end
end
