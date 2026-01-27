RSpec.describe Smolagents::Utilities::Prompts::Agent::ToolFormatting do
  # Create a test class that includes the module
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

      it "formats tool with signature, example, and description" do
        result = formatter.format_tool(tool)

        expect(result).to include("search(query: string)")
        expect(result).to include("Search the web")
        expect(result).to include("Example:")
      end

      it "includes return hint for output_type" do
        result = formatter.format_tool(tool)

        expect(result).to include("-> String")
      end

      it "builds example with result assignment" do
        result = formatter.format_tool(tool)

        expect(result).to include("result =")
        expect(result).to include("search(")
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

      it "omits return hint" do
        result = formatter.format_tool(tool)

        expect(result).not_to match(/-> \w+/)
      end
    end
  end

  describe "#build_return_hint" do
    it "returns empty string when output_type is nil" do
      tool = instance_double(Smolagents::Tool, output_type: nil)
      result = formatter.build_return_hint(tool)

      expect(result).to eq("")
    end

    it "returns formatted hint for output_type" do
      tool = instance_double(Smolagents::Tool, output_type: "string")
      result = formatter.build_return_hint(tool)

      expect(result).to eq(" -> String")
    end

    it "capitalizes output_type" do
      tool = instance_double(Smolagents::Tool, output_type: "boolean")
      result = formatter.build_return_hint(tool)

      expect(result).to eq(" -> Boolean")
    end

    it "handles missing output_type method" do
      tool = instance_double(Smolagents::Tool)
      allow(tool).to receive(:respond_to?).with(:output_type).and_return(false)
      result = formatter.build_return_hint(tool)

      expect(result).to eq("")
    end

    context "with output_schema" do
      it "shows array item properties for array of objects" do
        tool = instance_double(
          Smolagents::Tool,
          output_type: "array",
          output_schema: {
            type: "array",
            items: {
              type: "object",
              properties: { title: { type: "string" }, url: { type: "string" } }
            }
          }
        )
        result = formatter.build_return_hint(tool)

        expect(result).to include("Array<{")
        expect(result).to include("title")
        expect(result).to include("url")
      end

      it "shows array item type for simple arrays" do
        tool = instance_double(
          Smolagents::Tool,
          output_type: "array",
          output_schema: { type: "array", items: { type: "string" } }
        )
        result = formatter.build_return_hint(tool)

        expect(result).to eq(" -> Array<String>")
      end

      it "shows object properties for object type" do
        tool = instance_double(
          Smolagents::Tool,
          output_type: "object",
          output_schema: {
            type: "object",
            properties: { count: { type: "integer" }, name: { type: "string" } }
          }
        )
        result = formatter.build_return_hint(tool)

        expect(result).to include("Object{")
        expect(result).to include("count")
        expect(result).to include("name")
      end

      it "handles simple property-based schema" do
        tool = instance_double(
          Smolagents::Tool,
          output_type: "object",
          output_schema: {
            word_count: { type: "integer" },
            char_count: { type: "integer" }
          }
        )
        result = formatter.build_return_hint(tool)

        expect(result).to include("Object{")
        expect(result).to include("word_count")
        expect(result).to include("char_count")
      end

      it "truncates long property lists with ellipsis" do
        tool = instance_double(
          Smolagents::Tool,
          output_type: "object",
          output_schema: {
            a: { type: "string" },
            b: { type: "string" },
            c: { type: "string" },
            d: { type: "string" },
            e: { type: "string" }
          }
        )
        result = formatter.build_return_hint(tool)

        expect(result).to include("...")
      end
    end
  end

  describe "#build_signature" do
    it "returns name with empty parentheses for no inputs" do
      tool = instance_double(
        Smolagents::Tool,
        name: "action",
        inputs: {}
      )
      result = formatter.build_signature(tool)

      expect(result).to eq("action()")
    end

    it "includes input parameters in signature" do
      tool = instance_double(
        Smolagents::Tool,
        name: "search",
        inputs: {
          query: { type: "string" },
          limit: { type: "integer" }
        }
      )
      result = formatter.build_signature(tool)

      expect(result).to include("query: string")
      expect(result).to include("limit: integer")
    end

    it "handles nil inputs" do
      tool = instance_double(Smolagents::Tool, name: "test", inputs: nil)
      result = formatter.build_signature(tool)

      expect(result).to eq("test()")
    end

    it "marks nullable parameters with ?" do
      tool = instance_double(
        Smolagents::Tool,
        name: "fetch",
        inputs: {
          url: { type: "string" },
          timeout: { type: "integer", nullable: true }
        }
      )
      result = formatter.build_signature(tool)

      expect(result).to include("timeout: integer?")
    end
  end

  describe "#format_param_signature" do
    it "formats parameter with type" do
      spec = { type: "string" }
      result = formatter.format_param_signature(:query, spec)

      expect(result).to eq("query: string")
    end

    it "handles type from nested hash" do
      spec = { "type" => "integer" }
      result = formatter.format_param_signature(:count, spec)

      expect(result).to eq("count: integer")
    end

    it "marks nullable parameters" do
      spec = { type: "string", nullable: true }
      result = formatter.format_param_signature(:optional, spec)

      expect(result).to eq("optional: string?")
    end

    it "marks nullable using nested key" do
      spec = { "type" => "boolean", "nullable" => true }
      result = formatter.format_param_signature(:flag, spec)

      expect(result).to eq("flag: boolean?")
    end

    it "handles missing type" do
      spec = { description: "Something" }
      result = formatter.format_param_signature(:param, spec)

      expect(result).to eq("param: ")
    end
  end

  describe "#build_example" do
    it "returns example with no arguments for empty inputs" do
      tool = instance_double(
        Smolagents::Tool,
        name: "trigger",
        inputs: {},
        output_type: nil
      )
      result = formatter.build_example(tool)

      expect(result).to include("result = trigger()")
    end

    it "includes arguments in example" do
      tool = instance_double(
        Smolagents::Tool,
        name: "search",
        inputs: { query: { type: "string", description: "search term" } },
        output_type: "string"
      )
      result = formatter.build_example(tool)

      expect(result).to include("result = search(query:")
      expect(result).to include("# Returns string directly")
    end

    it "handles nil inputs" do
      tool = instance_double(
        Smolagents::Tool,
        name: "action",
        inputs: nil,
        output_type: nil
      )
      result = formatter.build_example(tool)

      expect(result).to eq("result = action()")
    end

    it "includes return comment for output_type" do
      tool = instance_double(
        Smolagents::Tool,
        name: "func",
        inputs: {},
        output_type: "array"
      )
      result = formatter.build_example(tool)

      expect(result).to include("# Returns array directly")
    end
  end

  describe "#build_return_comment" do
    it "returns empty string when output_type is nil" do
      tool = instance_double(Smolagents::Tool, output_type: nil)
      result = formatter.build_return_comment(tool)

      expect(result).to eq("")
    end

    it "returns formatted comment for output_type" do
      tool = instance_double(Smolagents::Tool, output_type: "string")
      result = formatter.build_return_comment(tool)

      expect(result).to eq("  # Returns string directly")
    end

    it "includes proper spacing" do
      tool = instance_double(Smolagents::Tool, output_type: "hash")
      result = formatter.build_return_comment(tool)

      expect(result).to start_with("  #")
    end
  end

  describe "#format_example_arg" do
    it "formats argument with inferred value" do
      spec = { type: "string", description: "search query" }
      result = formatter.format_example_arg(:query, spec)

      expect(result).to include("query:")
      expect(result.split(":").length).to be > 1
    end

    it "handles different parameter names" do
      spec = { type: "string", description: "file path" }
      result = formatter.format_example_arg(:path, spec)

      expect(result).to include("path:")
    end

    it "inspects the example value" do
      spec = { type: "string", description: "text" }
      result = formatter.format_example_arg(:text, spec)

      # Should be a quoted string due to inspect
      expect(result).to match(/".*"/)
    end

    it "handles type without description" do
      spec = { type: "integer" }
      result = formatter.format_example_arg(:count, spec)

      expect(result).to include("count:")
      expect(result).to be_a(String)
    end

    it "delegates example inference to Templates" do
      spec = { type: "string", description: "query" }
      allow(Smolagents::Utilities::Prompts::Templates).to receive(:example_for_type).and_return("example")

      formatter.format_example_arg(:q, spec)

      expect(Smolagents::Utilities::Prompts::Templates).to have_received(:example_for_type)
    end
  end
end
