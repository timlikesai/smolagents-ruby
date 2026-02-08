RSpec.describe Smolagents::Utilities::Prompts::Agent::ToolFormatting do
  let(:formatter) do
    Class.new do
      include Smolagents::Utilities::Prompts::Agent::ToolFormatting
    end.new
  end

  describe "#format_tool" do
    context "with string tool" do
      it "returns formatted string tool" do
        result = formatter.format_tool("search")

        expect(result).to eq("- search")
      end
    end

    context "with Tool object" do
      let(:tool) do
        instance_double(
          Smolagents::Tool,
          name: "search",
          description: "Search the web",
          inputs: { query: { type: "string", description: "Search query" } },
          output_type: "string"
        )
      end

      it "formats tool as YARD-style method stub" do
        result = formatter.format_tool(tool)

        expect(result).to include("# Search the web")
        expect(result).to include("# @param query [String] Search query")
        expect(result).to include("# @return [String]")
        expect(result).to include("def search(query:) = ...")
      end

      it "includes YARD @example tag" do
        result = formatter.format_tool(tool)

        expect(result).to include("# @example")
        expect(result).to include("#   result = search(query:")
      end
    end

    context "with tool without output_type" do
      let(:tool) do
        instance_double(
          Smolagents::Tool,
          name: "action",
          description: "Perform action",
          inputs: {},
          output_type: nil
        )
      end

      it "omits @return tag" do
        result = formatter.format_tool(tool)

        expect(result).not_to include("@return")
      end
    end

    context "with nullable parameter" do
      let(:tool) do
        instance_double(
          Smolagents::Tool,
          name: "fetch",
          description: "Fetch data",
          inputs: {
            url: { type: "string", description: "URL" },
            timeout: { type: "integer", description: "Timeout", nullable: true }
          },
          output_type: "string"
        )
      end

      it "marks nullable params with nil union" do
        result = formatter.format_tool(tool)

        expect(result).to include("# @param timeout [Integer, nil] Timeout")
        expect(result).to include("# @param url [String] URL")
      end
    end

    context "with no inputs" do
      let(:tool) do
        instance_double(
          Smolagents::Tool,
          name: "trigger",
          description: "Trigger action",
          inputs: {},
          output_type: nil
        )
      end

      it "renders empty keyword params" do
        result = formatter.format_tool(tool)

        expect(result).to include("def trigger() = ...")
      end
    end

    context "with nil inputs" do
      let(:tool) do
        instance_double(
          Smolagents::Tool,
          name: "test",
          description: "Test",
          inputs: nil,
          output_type: nil
        )
      end

      it "handles nil inputs gracefully" do
        result = formatter.format_tool(tool)

        expect(result).to include("def test() = ...")
      end
    end
  end

  describe "#format_tool with final_answer" do
    let(:final_answer_tool) do
      instance_double(
        Smolagents::Tool,
        name: "final_answer",
        description: "Return the final answer",
        inputs: { answer: { type: "string", description: "The answer" } },
        output_type: "string"
      )
    end

    it "uses >>> REQUIRED prefix for final_answer tool" do
      result = formatter.format_tool(final_answer_tool)

      expect(result).to start_with("# >>>")
      expect(result).to include("REQUIRED")
    end

    it "includes YARD @param for answer" do
      result = formatter.format_tool(final_answer_tool)

      expect(result).to include("# @param answer [String] The answer")
    end

    it "includes example with summarized result" do
      result = formatter.format_tool(final_answer_tool)

      expect(result).to include('final_answer(answer: "The result is 42")')
    end

    it "renders def stub" do
      result = formatter.format_tool(final_answer_tool)

      expect(result).to include("def final_answer(answer:) = ...")
    end
  end

  describe "RUBY_TYPE_MAP" do
    it "maps schema types to Ruby types" do
      map = described_class::RUBY_TYPE_MAP

      expect(map["string"]).to eq("String")
      expect(map["integer"]).to eq("Integer")
      expect(map["number"]).to eq("Numeric")
      expect(map["boolean"]).to eq("Boolean")
      expect(map["array"]).to eq("Array")
      expect(map["object"]).to eq("Hash")
    end
  end

  describe "output_schema return types" do
    context "with array of objects" do
      it "shows typed hash keys in Array" do
        tool = instance_double(
          Smolagents::Tool,
          name: "search",
          description: "Search",
          inputs: {},
          output_type: "array",
          output_schema: {
            type: "array",
            items: {
              type: "object",
              properties: { title: { type: "string" }, url: { type: "string" } }
            }
          }
        )
        result = formatter.format_tool(tool)

        expect(result).to include("Array<Hash{title: String, url: String}>")
      end
    end

    context "with simple array" do
      it "shows element type" do
        tool = instance_double(
          Smolagents::Tool,
          name: "list",
          description: "List items",
          inputs: {},
          output_type: "array",
          output_schema: { type: "array", items: { type: "string" } }
        )
        result = formatter.format_tool(tool)

        expect(result).to include("@return [Array<String>]")
      end
    end

    context "with object type" do
      it "shows typed hash keys" do
        tool = instance_double(
          Smolagents::Tool,
          name: "stats",
          description: "Get stats",
          inputs: {},
          output_type: "object",
          output_schema: {
            type: "object",
            properties: { count: { type: "integer" }, name: { type: "string" } }
          }
        )
        result = formatter.format_tool(tool)

        expect(result).to include("Hash{count: Integer, name: String}")
      end
    end

    context "with simple property-based schema" do
      it "shows typed keys from bare schema" do
        tool = instance_double(
          Smolagents::Tool,
          name: "count",
          description: "Count items",
          inputs: {},
          output_type: "object",
          output_schema: {
            word_count: { type: "integer" },
            char_count: { type: "integer" }
          }
        )
        result = formatter.format_tool(tool)

        expect(result).to include("Hash{word_count: Integer, char_count: Integer}")
      end
    end

    context "with many properties" do
      it "truncates with ellipsis" do
        tool = instance_double(
          Smolagents::Tool,
          name: "info",
          description: "Get info",
          inputs: {},
          output_type: "object",
          output_schema: {
            type: "object",
            properties: {
              a: { type: "string" }, b: { type: "string" },
              c: { type: "string" }, d: { type: "string" }
            }
          }
        )
        result = formatter.format_tool(tool)

        expect(result).to include("...")
      end
    end
  end
end
