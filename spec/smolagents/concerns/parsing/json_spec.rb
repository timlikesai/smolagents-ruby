require "spec_helper"

RSpec.describe Smolagents::Concerns::Json do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Json
    end
  end
  let(:instance) { test_class.new }

  describe "#parse_json" do
    it "parses valid JSON" do
      result = instance.parse_json('{"key": "value", "number": 42}')

      expect(result).to eq({ "key" => "value", "number" => 42 })
    end

    it "parses JSON arrays" do
      result = instance.parse_json("[1, 2, 3]")

      expect(result).to eq([1, 2, 3])
    end

    it "handles UTF-8 content" do
      result = instance.parse_json('{"text": "Hello 世界"}')

      expect(result["text"]).to eq("Hello 世界")
    end

    it "sanitizes invalid UTF-8 sequences" do
      # Create a string with invalid UTF-8
      invalid = "{\"text\": \"Hello \xFF\xFEWorld\"}"

      result = instance.parse_json(invalid)

      expect(result["text"]).to be_a(String)
      expect(result["text"]).to include("Hello")
      expect(result["text"]).to include("World")
    end

    it "raises JSON::ParserError for invalid JSON" do
      expect { instance.parse_json("not json") }.to raise_error(JSON::ParserError)
    end
  end

  describe "#extract_json" do
    let(:data) do
      {
        "response" => {
          "items" => [
            { "name" => "Item 1" },
            { "name" => "Item 2" }
          ],
          "count" => 2
        }
      }
    end

    it "extracts nested data with single key" do
      result = instance.extract_json(data, "response")

      expect(result).to have_key("items")
      expect(result).to have_key("count")
    end

    it "extracts deeply nested data" do
      result = instance.extract_json(data, "response", "items")

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it "returns nil for missing path" do
      result = instance.extract_json(data, "missing", "path")

      expect(result).to be_nil
    end

    it "handles nil data gracefully" do
      result = instance.extract_json(nil, "any", "path")

      expect(result).to be_nil
    end
  end

  describe "#to_json_string" do
    it "serializes hash to JSON" do
      result = instance.to_json_string({ status: "ok", count: 42 })

      expect(result).to eq('{"status":"ok","count":42}')
    end

    it "serializes arrays" do
      result = instance.to_json_string([1, 2, 3])

      expect(result).to eq("[1,2,3]")
    end

    it "sanitizes UTF-8 in nested structures" do
      data = { items: [{ text: "Hello\xFFWorld" }] }

      result = instance.to_json_string(data)

      expect(result).to include("Hello")
      expect(result).to include("World")
    end
  end
end
