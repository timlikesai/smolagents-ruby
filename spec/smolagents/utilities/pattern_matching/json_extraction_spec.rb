RSpec.describe Smolagents::Utilities::PatternMatching::JsonExtraction do
  describe ".extract" do
    it "extracts JSON from code block" do
      text = "Here is the result:\n```json\n{\"name\": \"test\", \"value\": 42}\n```"
      result = described_class.extract(text)

      expect(result).to be_a(Hash)
      expect(result["name"]).to eq("test")
      expect(result["value"]).to eq(42)
    end

    it "extracts inline JSON object" do
      text = 'The result is {"key": "value", "number": 123}'
      result = described_class.extract(text)

      expect(result).to be_a(Hash)
      expect(result["key"]).to eq("value")
    end

    it "extracts nested JSON structure" do
      text = "```json\n{\"outer\": {\"inner\": \"value\"}}\n```"
      result = described_class.extract(text)

      expect(result["outer"]["inner"]).to eq("value")
    end

    it "extracts JSON array" do
      text = "```json\n[1, 2, 3, 4, 5]\n```"
      result = described_class.extract(text)

      expect(result).to be_an(Array)
      expect(result).to contain_exactly(1, 2, 3, 4, 5)
    end

    it "extracts JSON with string values containing braces" do
      text = "```json\n{\"text\": \"This has {braces}\"}\n```"
      result = described_class.extract(text)

      expect(result["text"]).to eq("This has {braces}")
    end

    it "prefers code block over inline" do
      text = "inline: {\"inline\": true}\n```json\n{\"codeblock\": true}\n```"
      result = described_class.extract(text)

      expect(result).to have_key("codeblock")
      expect(result).not_to have_key("inline")
    end

    it "returns nil when JSON is invalid in code block" do
      text = "```json\n{invalid json}\n```"
      result = described_class.extract(text)

      expect(result).to be_nil
    end

    it "returns nil when no JSON found" do
      text = "This is just plain text with no JSON"
      result = described_class.extract(text)

      expect(result).to be_nil
    end

    it "returns nil when JSON is malformed" do
      text = 'Invalid: {"key": "value"'
      result = described_class.extract(text)

      expect(result).to be_nil
    end

    it "extracts multiline JSON" do
      text = %(```json
{
  "name": "test",
  "nested": {
    "field": "value"
  }
}
```
)
      result = described_class.extract(text)

      expect(result["name"]).to eq("test")
      expect(result["nested"]["field"]).to eq("value")
    end

    it "handles escaped quotes in JSON" do
      text = "```json\n{\"text\": \"He said \\\"hello\\\"\"}\n```"
      result = described_class.extract(text)

      expect(result["text"]).to include("hello")
    end

    it "extracts JSON with numbers and booleans" do
      text = "```json\n{\"count\": 42, \"enabled\": true, \"rate\": 3.14}\n```"
      result = described_class.extract(text)

      expect(result["count"]).to eq(42)
      expect(result["enabled"]).to be true
      expect(result["rate"]).to eq(3.14)
    end

    it "extracts JSON with null values" do
      text = "```json\n{\"value\": null}\n```"
      result = described_class.extract(text)

      expect(result["value"]).to be_nil
    end

    it "extracts inline JSON when no code block present" do
      text = "The response was: {\"success\": true}"
      result = described_class.extract(text)

      expect(result["success"]).to be true
    end

    it "handles JSON with numeric keys" do
      text = "```json\n{\"1\": \"one\", \"2\": \"two\"}\n```"
      result = described_class.extract(text)

      expect(result["1"]).to eq("one")
      expect(result["2"]).to eq("two")
    end

    it "extracts first valid JSON when multiple exist" do
      text = "{\"first\": 1}\n```json\n{\"second\": 2}\n```"
      result = described_class.extract(text)

      # Should prefer code block
      expect(result["second"]).to eq(2)
    end

    it "returns nil for empty code block" do
      text = "```json\n\n```"
      result = described_class.extract(text)

      expect(result).to be_nil
    end

    it "handles JSON with special characters" do
      text = "```json\n{\"emoji\": \"\u{1F600}\", \"symbol\": \"$\"}\n```"
      result = described_class.extract(text)

      expect(result["emoji"]).to eq("\u{1F600}")
      expect(result["symbol"]).to eq("$")
    end
  end
end
