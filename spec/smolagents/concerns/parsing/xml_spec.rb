require "spec_helper"

RSpec.describe Smolagents::Concerns::Xml do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Xml
    end
  end
  let(:instance) { test_class.new }

  let(:sample_rss) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>First Article</title>
            <link>https://example.com/1</link>
            <description>Description of first article</description>
          </item>
          <item>
            <title>Second Article</title>
            <link>https://example.com/2</link>
            <description>Description of second article</description>
          </item>
        </channel>
      </rss>
    XML
  end

  # Atom feed without namespace for simpler XPath (real feeds may have namespace)
  let(:sample_atom) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <feed>
        <title>Atom Feed</title>
        <entry>
          <title>Entry One</title>
          <link href="https://example.com/entry1"/>
          <summary>Summary of entry one</summary>
        </entry>
        <entry>
          <title>Entry Two</title>
          <link href="https://example.com/entry2"/>
          <content>Content of entry two</content>
        </entry>
      </feed>
    XML
  end

  describe "#parse_xml" do
    it "parses XML into Nokogiri document" do
      doc = instance.parse_xml(sample_rss)

      expect(doc).to be_a(Nokogiri::XML::Document)
    end

    it "allows XPath selection on parsed document" do
      doc = instance.parse_xml(sample_rss)

      expect(doc.xpath("//item").length).to eq(2)
    end
  end

  describe "#xpath_select" do
    it "selects elements with XPath" do
      elements = instance.xpath_select(sample_rss, "//item")

      expect(elements.length).to eq(2)
    end

    it "works with pre-parsed document" do
      doc = instance.parse_xml(sample_rss)
      elements = instance.xpath_select(doc, "//item")

      expect(elements.length).to eq(2)
    end

    it "limits results when limit provided" do
      elements = instance.xpath_select(sample_rss, "//item", limit: 1)

      expect(elements.length).to eq(1)
    end

    it "transforms elements with block" do
      titles = instance.xpath_select(sample_rss, "//item") do |item|
        item.at_xpath("title")&.text
      end

      expect(titles).to eq(["First Article", "Second Article"])
    end

    it "returns empty result for no matches" do
      elements = instance.xpath_select(sample_rss, "//nonexistent")

      expect(elements).to be_empty
    end
  end

  describe "#xpath_text" do
    it "extracts text from XPath" do
      doc = instance.parse_xml(sample_rss)
      item = doc.at_xpath("//item")

      result = instance.xpath_text(item, "title")

      expect(result).to eq("First Article")
    end

    it "returns nil for missing element" do
      doc = instance.parse_xml(sample_rss)
      item = doc.at_xpath("//item")

      result = instance.xpath_text(item, "nonexistent")

      expect(result).to be_nil
    end

    it "strips whitespace" do
      xml = "<root><item>  text with spaces  </item></root>"
      doc = instance.parse_xml(xml)
      root = doc.at_xpath("//root")

      result = instance.xpath_text(root, "item")

      expect(result).to eq("text with spaces")
    end
  end

  describe "#parse_rss_items" do
    it "parses RSS items into standardized hashes" do
      items = instance.parse_rss_items(sample_rss)

      expect(items.length).to eq(2)
      expect(items.first).to include(
        title: "First Article",
        link: "https://example.com/1",
        description: "Description of first article"
      )
    end

    it "limits items when limit provided" do
      items = instance.parse_rss_items(sample_rss, limit: 1)

      expect(items.length).to eq(1)
    end

    it "works with pre-parsed document" do
      doc = instance.parse_xml(sample_rss)
      items = instance.parse_rss_items(doc)

      expect(items.length).to eq(2)
    end
  end

  describe "#parse_atom_entries" do
    it "parses Atom entries into standardized hashes" do
      entries = instance.parse_atom_entries(sample_atom)

      expect(entries.length).to eq(2)
      expect(entries.first).to include(
        title: "Entry One",
        link: "https://example.com/entry1",
        description: "Summary of entry one"
      )
    end

    it "falls back to content when summary missing" do
      entries = instance.parse_atom_entries(sample_atom)

      expect(entries[1][:description]).to eq("Content of entry two")
    end

    it "limits entries when limit provided" do
      entries = instance.parse_atom_entries(sample_atom, limit: 1)

      expect(entries.length).to eq(1)
    end
  end
end
