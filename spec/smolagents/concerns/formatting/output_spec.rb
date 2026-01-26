require "spec_helper"

RSpec.describe Smolagents::Concerns::ResultFormatting do
  subject(:formatter) { test_class.new }

  let(:test_class) do
    Class.new do
      attr_accessor :data

      include Smolagents::Concerns::ResultFormatting

      def to_a = Array(data)
    end
  end

  describe "#as_markdown" do
    # Set formatter.data only for contexts that define data
    before { formatter.data = data }

    context "with arrays" do
      let(:data) { %w[item1 item2 item3] }

      it "formats as bullet list" do
        result = formatter.as_markdown
        expect(result).to eq("- item1\n- item2\n- item3")
      end

      it "returns empty for empty array" do
        formatter.data = []
        expect(formatter.as_markdown).to eq("*(empty)*")
      end

      it "limits items with max_items" do
        result = formatter.as_markdown(max_items: 2)
        expect(result).to eq("- item1\n- item2")
      end
    end

    context "with array of hashes" do
      let(:data) do
        [
          { "title" => "First", "url" => "http://a.com" },
          { "title" => "Second", "url" => "http://b.com" }
        ]
      end

      it "formats with numbered list" do
        result = formatter.as_markdown
        expect(result).to include("**1.**")
        expect(result).to include("**2.**")
        expect(result).to include("**title:** First")
        expect(result).to include("**url:** http://a.com")
      end
    end

    context "with hashes" do
      let(:data) { { "name" => "Ruby", "version" => "4.0" } }

      it "formats key-value pairs" do
        result = formatter.as_markdown
        expect(result).to include("**name:** Ruby")
        expect(result).to include("**version:** 4.0")
      end

      it "joins multiple values with commas" do
        formatter.data = { "tags" => %w[ruby agent ai] }
        result = formatter.as_markdown
        expect(result).to include("ruby, agent, ai")
      end
    end

    context "with nil" do
      let(:data) { nil }

      it "returns empty string" do
        expect(formatter.as_markdown).to eq("")
      end
    end

    context "with scalar" do
      let(:data) { "simple string" }

      it "converts to string" do
        expect(formatter.as_markdown).to eq("simple string")
      end
    end
  end

  describe "#as_list" do
    let(:data) { %w[alpha beta gamma] }

    before { formatter.data = data }

    it "formats with default dash bullet" do
      result = formatter.as_list
      expect(result).to eq("- alpha\n- beta\n- gamma")
    end

    it "formats with custom bullet" do
      result = formatter.as_list(bullet: "*")
      expect(result).to eq("* alpha\n* beta\n* gamma")
    end

    it "formats hashes inline" do
      formatter.data = [{ "key" => "value", "foo" => "bar" }]
      result = formatter.as_list
      expect(result).to include("key: value")
      expect(result).to include("foo: bar")
    end
  end

  describe "#as_numbered_list" do
    let(:data) { %w[first second third] }

    before { formatter.data = data }

    it "formats with numbers" do
      result = formatter.as_numbered_list
      expect(result).to eq("1. first\n2. second\n3. third")
    end

    it "handles empty array" do
      formatter.data = []
      expect(formatter.as_numbered_list).to eq("")
    end
  end

  describe "#to_json" do
    let(:data) { { "name" => "test", "count" => 42 } }

    before { formatter.data = data }

    it "converts to JSON" do
      result = formatter.to_json
      expect(JSON.parse(result)).to eq("name" => "test", "count" => 42)
    end

    it "returns valid JSON" do
      result = formatter.to_json
      parsed = JSON.parse(result)
      expect(parsed["name"]).to eq("test")
      expect(parsed["count"]).to eq(42)
    end
  end

  describe "#as_yaml" do
    let(:data) { { name: "test", items: [1, 2, 3] } }

    before { formatter.data = data }

    it "converts to YAML" do
      result = formatter.as_yaml
      expect(result).to include("name: test")
      expect(result).to include("items:")
    end
  end

  describe "#as_table" do
    before { formatter.data = data }

    context "with array of hashes" do
      let(:data) do
        [
          { "id" => 1, "name" => "Alice" },
          { "id" => 2, "name" => "Bob" }
        ]
      end

      it "formats as ASCII table" do
        result = formatter.as_table
        # Table uses "id | name" format (no leading/trailing pipes)
        expect(result).to include("id | name")
        expect(result).to include("---")
        expect(result).to include("1")
        expect(result).to include("Alice")
        expect(result).to include("Bob")
      end

      it "applies max_width to columns" do
        formatter.data = [{ "long_content" => "x" * 100 }]
        result = formatter.as_table(max_width: 15)
        expect(result).to include("...")
      end
    end

    context "with non-hash arrays" do
      let(:data) { %w[a b c] }

      it "falls back to to_s" do
        result = formatter.as_table
        expect(result).to eq(data.to_s)
      end
    end

    context "with empty array" do
      let(:data) { [] }

      it "falls back to to_s" do
        result = formatter.as_table
        expect(result).to eq("[]")
      end
    end
  end

  describe "private methods" do
    describe "#format_hash_markdown" do
      it "formats hash entries" do
        hash = { "key1" => "value1", "key2" => "value2" }
        result = formatter.send(:format_hash_markdown, hash)
        expect(result).to include("**key1:** value1")
        expect(result).to include("**key2:** value2")
      end
    end

    describe "#format_value" do
      it "joins arrays with commas" do
        value = %w[a b c]
        result = formatter.send(:format_value, value)
        expect(result).to eq("a, b, c")
      end

      it "converts non-arrays to string" do
        expect(formatter.send(:format_value, 42)).to eq(42)
      end
    end

    describe "#format_array_markdown" do
      it "returns empty message for empty array" do
        result = formatter.send(:format_array_markdown, [])
        expect(result).to eq("*(empty)*")
      end

      it "formats simple items as bullets" do
        result = formatter.send(:format_array_markdown, %w[x y])
        expect(result).to eq("- x\n- y")
      end

      it "formats hash items as numbered" do
        items = [{ "a" => 1 }, { "b" => 2 }]
        result = formatter.send(:format_array_markdown, items)
        expect(result).to include("**1.**")
        expect(result).to include("**2.**")
      end
    end

    describe "#format_hash_inline" do
      it "formats inline key-value pairs" do
        hash = { "key" => "val", "foo" => "bar" }
        result = formatter.send(:format_hash_inline, hash)
        expect(result).to include("**key:** val")
        expect(result).to include("**foo:** bar")
      end
    end

    describe "#format_item" do
      it "formats simple items" do
        expect(formatter.send(:format_item, "test")).to eq("test")
      end

      it "formats hashes" do
        item = { "a" => 1, "b" => 2 }
        result = formatter.send(:format_item, item)
        expect(result).to include("a: 1")
        expect(result).to include("b: 2")
      end
    end
  end
end
