require "spec_helper"

RSpec.describe Smolagents::Tools::SearchTool::ResponseParser do
  let(:json_search_class) do
    Class.new(Smolagents::Tools::SearchTool) do
      configure do |c|
        c.name "json_search"
        c.description "JSON search tool"
        c.endpoint "https://api.example.com/search"
        c.parses :json
        c.results_path "data", "items"
        c.field_mapping title: "name", link: "url", description: "desc"
      end
    end
  end

  describe "#parse_response" do
    context "with JSON parser" do
      let(:tool) { json_search_class.new }

      before do
        stub_request(:get, /api\.example\.com/).to_return(
          status: 200,
          body: {
            data: {
              items: [
                { name: "Result 1", url: "https://example.com/1", desc: "First result" },
                { name: "Result 2", url: "https://example.com/2", desc: "Second result" }
              ]
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "extracts and maps results from nested path" do
        results = tool.execute(query: "test")

        expect(results).to contain_exactly(
          a_hash_including(title: "Result 1", link: "https://example.com/1"),
          a_hash_including(title: "Result 2", link: "https://example.com/2")
        )
      end
    end

    context "with HTML parser" do
      let(:html_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "html_search"
            c.description "HTML search tool"
            c.endpoint "https://example.com/search"
            c.parses :html
            c.html_results "div.result"
            c.html_field :title, selector: "h3", extract: :text
            c.html_field :link, selector: "a", extract: :href
            c.html_field :description, selector: "p.desc", extract: :text
          end
        end
      end

      let(:tool) { html_search_class.new }

      before do
        html = <<~HTML
          <html>
            <body>
              <div class="result">
                <h3>First Result</h3>
                <a href="https://example.com/1">Link</a>
                <p class="desc">Description one</p>
              </div>
              <div class="result">
                <h3>Second Result</h3>
                <a href="https://example.com/2">Link</a>
                <p class="desc">Description two</p>
              </div>
            </body>
          </html>
        HTML

        stub_request(:get, %r{example\.com/search}).to_return(
          status: 200,
          body: html,
          headers: { "Content-Type" => "text/html" }
        )
      end

      it "extracts results from HTML using CSS selectors" do
        results = tool.execute(query: "test")

        expect(results).to contain_exactly(
          a_hash_including(title: "First Result", link: "https://example.com/1"),
          a_hash_including(title: "Second Result", link: "https://example.com/2")
        )
      end
    end

    context "with strip_html configuration" do
      let(:strip_html_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "strip_search"
            c.description "Strip HTML search"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.results_path "results"
            c.field_mapping title: "title", link: "link", description: "description"
            c.strip_html :description
          end
        end
      end

      let(:tool) { strip_html_search_class.new }

      before do
        stub_request(:get, /api\.example\.com/).to_return(
          status: 200,
          body: {
            results: [
              {
                title: "Result",
                link: "https://example.com",
                description: "<p>This is <b>bold</b> text</p>"
              }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "strips HTML tags from specified fields" do
        results = tool.execute(query: "test")

        expect(results.first[:description]).to eq("This is bold text")
      end
    end

    context "with link_builder" do
      let(:link_builder_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "link_builder_search"
            c.description "Link builder search"
            c.endpoint "https://api.example.com/search"
            c.parses :json
            c.results_path "results"
            c.field_mapping title: "title", link: "path", description: "desc"
            c.link_builder { |raw| "https://example.com#{raw["path"]}" }
          end
        end
      end

      let(:tool) { link_builder_search_class.new }

      before do
        stub_request(:get, /api\.example\.com/).to_return(
          status: 200,
          body: {
            results: [
              { title: "Result", path: "/page/1", desc: "Description" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "builds links using the custom builder" do
        results = tool.execute(query: "test")

        expect(results.first[:link]).to eq("https://example.com/page/1")
      end
    end

    context "with nested HTML field selector" do
      let(:nested_html_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "nested_search"
            c.description "Nested HTML search"
            c.endpoint "https://example.com/search"
            c.parses :html
            c.html_results "div.result"
            c.html_field :title, selector: "div.header", nested: "span.title", extract: :text
            c.html_field :link, selector: "a", extract: :href
          end
        end
      end

      let(:tool) { nested_html_search_class.new }

      before do
        html = <<~HTML
          <html>
            <body>
              <div class="result">
                <div class="header">
                  <span class="title">Nested Title</span>
                </div>
                <a href="https://example.com/1">Link</a>
              </div>
            </body>
          </html>
        HTML

        stub_request(:get, %r{example\.com/search}).to_return(
          status: 200,
          body: html,
          headers: { "Content-Type" => "text/html" }
        )
      end

      it "extracts from nested elements" do
        results = tool.execute(query: "test")

        expect(results.first[:title]).to eq("Nested Title")
      end
    end

    context "with prefix and suffix affixes" do
      let(:affix_html_search_class) do
        Class.new(Smolagents::Tools::SearchTool) do
          configure do |c|
            c.name "affix_search"
            c.description "Affix HTML search"
            c.endpoint "https://example.com/search"
            c.parses :html
            c.html_results "div.result"
            c.html_field :title, selector: "h3", extract: :text
            c.html_field :link, selector: "a", extract: :href, prefix: "https://example.com"
          end
        end
      end

      let(:tool) { affix_html_search_class.new }

      before do
        html = <<~HTML
          <html>
            <body>
              <div class="result">
                <h3>Title</h3>
                <a href="/page/1">Link</a>
              </div>
            </body>
          </html>
        HTML

        stub_request(:get, %r{example\.com/search}).to_return(
          status: 200,
          body: html,
          headers: { "Content-Type" => "text/html" }
        )
      end

      it "applies prefix to extracted value" do
        results = tool.execute(query: "test")

        expect(results.first[:link]).to eq("https://example.com/page/1")
      end
    end

    context "with max_results limit" do
      let(:tool) { json_search_class.new(max_results: 1) }

      before do
        stub_request(:get, /api\.example\.com/).to_return(
          status: 200,
          body: {
            data: {
              items: [
                { name: "Result 1", url: "https://example.com/1", desc: "First" },
                { name: "Result 2", url: "https://example.com/2", desc: "Second" },
                { name: "Result 3", url: "https://example.com/3", desc: "Third" }
              ]
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "limits the number of results returned" do
        results = tool.execute(query: "test")

        expect(results.size).to eq(1)
        expect(results.first[:title]).to eq("Result 1")
      end
    end
  end

  describe "result validation" do
    let(:html_search_class) do
      Class.new(Smolagents::Tools::SearchTool) do
        configure do |c|
          c.name "validation_search"
          c.description "Validation search"
          c.endpoint "https://example.com/search"
          c.parses :html
          c.html_results "div.result"
          c.html_field :title, selector: "h3", extract: :text
          c.html_field :link, selector: "a", extract: :href
        end
      end
    end

    let(:tool) { html_search_class.new }

    before do
      html = <<~HTML
        <html>
          <body>
            <div class="result">
              <h3>Valid Result</h3>
              <a href="https://example.com/1">Link</a>
            </div>
            <div class="result">
              <!-- Missing title and link -->
            </div>
            <div class="result">
              <h3>Another Valid</h3>
              <a href="https://example.com/2">Link</a>
            </div>
          </body>
        </html>
      HTML

      stub_request(:get, %r{example\.com/search}).to_return(
        status: 200,
        body: html,
        headers: { "Content-Type" => "text/html" }
      )
    end

    it "filters out results without title or link" do
      results = tool.execute(query: "test")

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:title] }).to contain_exactly("Valid Result", "Another Valid")
    end
  end
end
