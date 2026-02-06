require "spec_helper"

RSpec.describe "Parsing concerns integration" do
  describe "integration" do
    let(:combined_parser) do
      Class.new do
        include Smolagents::Concerns::Json
        include Smolagents::Concerns::Html
        include Smolagents::Concerns::Xml
      end.new
    end

    describe "parsing pipeline" do
      it "can parse JSON embedded in HTML" do
        html = '<div id="data">{"items": [{"name": "Ruby"}]}</div>'
        doc = combined_parser.parse_html(html)
        json_text = combined_parser.text_content(doc.at_css("#data"))
        data = combined_parser.parse_json(json_text)

        expect(data["items"].first["name"]).to eq("Ruby")
      end

      it "can extract and parse RSS from XML" do
        rss = <<~XML
          <?xml version="1.0"?>
          <rss><channel>
            <item><title>Test</title><link>http://example.com</link></item>
          </channel></rss>
        XML

        items = combined_parser.parse_rss_items(rss)
        json = combined_parser.to_json_string(items)
        reparsed = combined_parser.parse_json(json)

        expect(reparsed.first["title"]).to eq("Test")
      end
    end

    describe "UTF-8 handling across parsers" do
      it "handles UTF-8 consistently between Json and Html" do
        json_parser = Class.new { include Smolagents::Concerns::Json }.new
        html_parser = Class.new { include Smolagents::Concerns::Html }.new

        json_data = json_parser.parse_json('{"text": "Hello 世界"}')
        html_text = html_parser.text_content(html_parser.parse_html("<p>Hello 世界</p>").at_css("p"))

        expect(json_data["text"]).to include("世界")
        expect(html_text).to include("世界")
      end
    end
  end
end
