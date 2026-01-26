require "webmock/rspec"

RSpec.describe Smolagents::ArxivSearchTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { query: "machine learning" } }
  let(:required_input_name) { :query }

  let(:sample_response) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <id>http://arxiv.org/abs/2301.12345v1</id>
          <title>A Great Paper on Machine Learning</title>
          <summary>This paper presents a novel approach to machine learning that achieves state-of-the-art results on multiple benchmarks.</summary>
          <author><name>Alice Smith</name></author>
          <author><name>Bob Jones</name></author>
          <published>2023-01-15T00:00:00Z</published>
          <category term="cs.LG"/>
          <category term="cs.AI"/>
        </entry>
      </feed>
    XML
  end

  before do
    stub_request(:get, "https://export.arxiv.org/api/query")
      .with(query: hash_including(search_query: "machine learning"))
      .to_return(status: 200, body: sample_response)
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("arxiv")
    end

    it "has a description mentioning academic papers" do
      expect(described_class.description).to include("academic")
    end

    it "parses XML responses" do
      expect(described_class.search_config.parser_type).to eq(:xml)
    end

    it "has default max_results of 5" do
      tool = described_class.new
      # Default is 5, max is 10 (protected attr, use send)
      expect(tool.send(:max_results)).to eq(5)
    end

    it "limits max_results to 10" do
      tool = described_class.new(max_results: 20)
      expect(tool.send(:max_results)).to eq(10)
    end
  end

  describe "#call" do
    context "when search succeeds" do
      it "returns formatted paper results" do
        result = tool.call(query: "machine learning")

        expect(result.to_s).to include("A Great Paper on Machine Learning")
        expect(result.to_s).to include("Alice Smith")
        expect(result.to_s).to include("http://arxiv.org/abs/2301.12345v1")
      end

      it "includes categories" do
        result = tool.call(query: "machine learning")

        expect(result.to_s).to include("cs.LG")
      end

      it "includes published date" do
        result = tool.call(query: "machine learning")

        expect(result.to_s).to include("2023-01-15")
      end
    end

    context "when no results" do
      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "xyznonexistent123"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
            </feed>
          XML
      end

      it "returns empty result" do
        result = tool.call(query: "xyznonexistent123")

        # Empty results are formatted as *(empty)*
        expect(result.data).to be_empty
      end
    end

    context "when HTTP error" do
      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "test"))
          .to_return(status: 500, body: "Internal error")
      end

      it "raises HttpError" do
        expect { tool.call(query: "test") }
          .to raise_error(Smolagents::HttpError)
      end
    end
  end

  describe "XML parsing edge cases" do
    context "with missing elements" do
      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "incomplete"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2301.99999v1</id>
                <title>Paper With Missing Fields</title>
              </entry>
            </feed>
          XML
      end

      it "handles missing summary gracefully" do
        result = tool.call(query: "incomplete")

        expect(result.to_s).to include("Paper With Missing Fields")
        # Should not raise error
      end

      it "handles missing author gracefully" do
        result = tool.call(query: "incomplete")

        expect(result.to_s).to include("Paper With Missing Fields")
      end
    end

    context "with special characters in text" do
      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "special"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2301.11111v1</id>
                <title>Analysis of α-β Pruning &amp; O(n²) Complexity</title>
                <summary>We study the &lt;algorithm&gt; with "special" chars: &amp;, &lt;, &gt;.</summary>
                <author><name>María García</name></author>
                <published>2023-02-20T00:00:00Z</published>
                <category term="cs.DS"/>
              </entry>
            </feed>
          XML
      end

      it "handles HTML entities correctly" do
        result = tool.call(query: "special")

        expect(result.to_s).to include("α-β Pruning")
        expect(result.to_s).to include("O(n²)")
      end

      it "handles special characters in author names" do
        result = tool.call(query: "special")

        expect(result.to_s).to include("María García")
      end
    end

    context "with many authors" do
      before do
        authors = (1..10).map { |i| "<author><name>Author #{i}</name></author>" }.join("\n")
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "many_authors"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2301.22222v1</id>
                <title>Collaborative Research Paper</title>
                <summary>A paper with many authors.</summary>
                #{authors}
                <published>2023-03-01T00:00:00Z</published>
                <category term="cs.CL"/>
              </entry>
            </feed>
          XML
      end

      it "limits authors to 5 with 'et al.'" do
        result = tool.call(query: "many_authors")

        expect(result.to_s).to include("Author 1")
        expect(result.to_s).to include("Author 5")
        expect(result.to_s).not_to include("Author 6")
        expect(result.to_s).to include("et al.")
      end
    end

    context "with long abstract" do
      let(:long_abstract) { "A" * 600 }

      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "long_abstract"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2301.33333v1</id>
                <title>Paper With Long Abstract</title>
                <summary>#{long_abstract}</summary>
                <author><name>Test Author</name></author>
                <published>2023-04-01T00:00:00Z</published>
                <category term="cs.AI"/>
              </entry>
            </feed>
          XML
      end

      it "handles long abstract in raw data" do
        result = tool.call(query: "long_abstract")

        # Raw data contains full abstract (truncation happens in format_paper)
        expect(result.data.first[:abstract]).to eq(long_abstract)
        expect(result.data.first[:title]).to eq("Paper With Long Abstract")
      end
    end

    context "with whitespace in text" do
      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "whitespace"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2301.44444v1</id>
                <title>  Paper   With   Extra    Whitespace  </title>
                <summary>
                  This   summary has
                  multiple lines and    extra
                  whitespace.
                </summary>
                <author><name>Clean Author</name></author>
                <published>2023-05-01T00:00:00Z</published>
                <category term="cs.LG"/>
              </entry>
            </feed>
          XML
      end

      it "normalizes whitespace in title" do
        result = tool.call(query: "whitespace")

        expect(result.to_s).to include("Paper With Extra Whitespace")
        expect(result.to_s).not_to include("  ")
      end

      it "normalizes whitespace in summary" do
        result = tool.call(query: "whitespace")

        # Check that multiple spaces/newlines are normalized
        expect(result.to_s).not_to match(/\s{2,}/)
      end
    end

    context "with multiple categories" do
      before do
        stub_request(:get, "https://export.arxiv.org/api/query")
          .with(query: hash_including(search_query: "multi_cat"))
          .to_return(status: 200, body: <<~XML)
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2301.55555v1</id>
                <title>Interdisciplinary Paper</title>
                <summary>Covers many areas.</summary>
                <author><name>Multi Author</name></author>
                <published>2023-06-01T00:00:00Z</published>
                <category term="cs.AI"/>
                <category term="cs.LG"/>
                <category term="cs.CL"/>
                <category term="cs.MA"/>
                <category term="stat.ML"/>
              </entry>
            </feed>
          XML
      end

      it "limits categories to 3" do
        result = tool.call(query: "multi_cat")

        expect(result.to_s).to include("cs.AI")
        expect(result.to_s).to include("cs.LG")
        expect(result.to_s).to include("cs.CL")
        expect(result.to_s).not_to include("cs.MA")
        expect(result.to_s).not_to include("stat.ML")
      end
    end
  end
end
