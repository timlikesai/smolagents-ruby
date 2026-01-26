require "spec_helper"

RSpec.describe Smolagents::Concerns::Html do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Html
    end
  end
  let(:instance) { test_class.new }

  let(:sample_html) do
    <<~HTML
      <html>
        <head><title>Test Page</title></head>
        <body>
          <h1 class="title">Main Title</h1>
          <div class="content">
            <p>First paragraph</p>
            <p>Second paragraph</p>
            <a href="https://example.com" class="link">Example Link</a>
            <a href="https://other.com" class="link">Other Link</a>
          </div>
        </body>
      </html>
    HTML
  end

  describe "#parse_html" do
    it "parses HTML into Nokogiri document" do
      doc = instance.parse_html(sample_html)

      expect(doc).to be_a(Nokogiri::HTML::Document)
    end

    it "allows CSS selection on parsed document" do
      doc = instance.parse_html(sample_html)

      expect(doc.css("h1.title").text).to eq("Main Title")
    end
  end

  describe "#css_select" do
    it "selects elements with CSS selector" do
      elements = instance.css_select(sample_html, "p")

      expect(elements.length).to eq(2)
    end

    it "works with pre-parsed document" do
      doc = instance.parse_html(sample_html)
      elements = instance.css_select(doc, "a.link")

      expect(elements.length).to eq(2)
    end

    it "limits results when limit provided" do
      elements = instance.css_select(sample_html, "p", limit: 1)

      expect(elements.length).to eq(1)
    end

    it "transforms elements with block" do
      texts = instance.css_select(sample_html, "p") { |el| el.text.strip }

      expect(texts).to eq(["First paragraph", "Second paragraph"])
    end

    it "combines limit and transformation" do
      texts = instance.css_select(sample_html, "p", limit: 1) { |el| el.text.strip }

      expect(texts).to eq(["First paragraph"])
    end

    it "returns empty result for no matches" do
      elements = instance.css_select(sample_html, "span.nonexistent")

      expect(elements).to be_empty
    end
  end

  describe "#strip_html_tags" do
    it "removes HTML tags from text" do
      result = instance.strip_html_tags("<p>Hello <b>world</b></p>")

      expect(result).to eq("Hello world")
    end

    it "handles nil gracefully" do
      result = instance.strip_html_tags(nil)

      expect(result).to eq("")
    end

    it "strips whitespace" do
      result = instance.strip_html_tags("  <p>text</p>  ")

      expect(result).to eq("text")
    end
  end

  describe "#text_content" do
    it "extracts text from element" do
      doc = instance.parse_html(sample_html)
      element = doc.at_css("h1.title")

      result = instance.text_content(element)

      expect(result).to eq("Main Title")
    end

    it "strips whitespace from text" do
      doc = instance.parse_html("<div>  text with spaces  </div>")
      element = doc.at_css("div")

      result = instance.text_content(element)

      expect(result).to eq("text with spaces")
    end

    it "handles nil element" do
      result = instance.text_content(nil)

      expect(result).to be_nil
    end
  end

  describe "#attr_value" do
    it "extracts attribute from element" do
      doc = instance.parse_html(sample_html)
      link = doc.at_css("a.link")

      result = instance.attr_value(link, "href")

      expect(result).to eq("https://example.com")
    end

    it "returns nil for missing attribute" do
      doc = instance.parse_html(sample_html)
      link = doc.at_css("a.link")

      result = instance.attr_value(link, "data-missing")

      expect(result).to be_nil
    end

    it "handles nil element" do
      result = instance.attr_value(nil, "href")

      expect(result).to be_nil
    end
  end
end
