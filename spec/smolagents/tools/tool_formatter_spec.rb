RSpec.describe Smolagents::Tools::ToolFormatter do
  # Create a simple test tool
  let(:test_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "test_search"
      self.description = "Search for information"
      self.inputs = {
        query: { type: "string", description: "Search query" },
        limit: { type: "integer", description: "Max results", nullable: true }
      }
      self.output_type = "array"

      def execute(_query:, _limit: 10)
        []
      end
    end.new
  end

  describe ".format" do
    context "with :code format" do
      it "formats as Ruby method signature" do
        result = described_class.format(test_tool, format: :code)

        expect(result).to eq("test_search(query: Search query, limit: Max results) - Search for information")
      end
    end

    context "with :tool_calling format" do
      it "formats as natural language description" do
        result = described_class.format(test_tool, format: :tool_calling)

        expect(result).to include("test_search: Search for information")
        expect(result).to include("Takes inputs:")
        expect(result).to include("Returns: array")
      end
    end

    context "with unknown format" do
      it "raises ArgumentError" do
        expect { described_class.format(test_tool, format: :unknown) }
          .to raise_error(ArgumentError, /Unknown tool format: unknown/)
      end

      it "lists available formats in error message" do
        expect { described_class.format(test_tool, format: :bad) }
          .to raise_error(ArgumentError, /Available: code, tool_calling, managed_agent/)
      end
    end
  end

  describe ".register" do
    it "allows custom formatters" do
      custom_formatter = Class.new do
        def format(tool)
          "CUSTOM: #{tool.name}"
        end
      end.new

      described_class.register(:custom_test, custom_formatter)
      result = described_class.format(test_tool, format: :custom_test)

      expect(result).to eq("CUSTOM: test_search")
    end
  end

  describe ".formats" do
    it "lists registered format names" do
      formats = described_class.formats

      expect(formats).to include(:code)
      expect(formats).to include(:tool_calling)
      expect(formats).to include(:managed_agent)
    end
  end

  describe "Tool#format_for" do
    it "delegates to ToolFormatter" do
      result = test_tool.format_for(:code)

      expect(result).to eq("test_search(query: Search query, limit: Max results) - Search for information")
    end
  end

  describe "InlineTool formatting" do
    let(:inline_tool) do
      Smolagents::Tools::InlineTool.create(:greet, "Greet a person", name: String) do |name:|
        "Hello, #{name}!"
      end
    end

    it "supports format_for(:code)" do
      result = inline_tool.format_for(:code)

      expect(result).to eq("greet(name: ) - Greet a person")
    end

    it "supports format_for(:tool_calling)" do
      result = inline_tool.format_for(:tool_calling)

      expect(result).to be_a(String)
      expect(result).to include("greet")
    end
  end

  describe Smolagents::Tools::ToolFormatter::CodeFormatter do
    it "formats tools as Ruby method signatures" do
      formatter = described_class.new
      result = formatter.format(test_tool)

      expect(result).to eq("test_search(query: Search query, limit: Max results) - Search for information")
    end
  end

  describe Smolagents::Tools::ToolFormatter::ToolCallingFormatter do
    it "formats tools as natural language" do
      formatter = described_class.new
      result = formatter.format(test_tool)

      expect(result).to start_with("test_search: Search for information")
      expect(result).to include("Takes inputs:")
      expect(result).to include("Returns: array")
    end
  end

  describe Smolagents::Tools::ToolFormatter::ManagedAgentFormatter do
    it "formats tools with delegation guidance" do
      formatter = described_class.new
      result = formatter.format(test_tool)

      expect(result).to include("test_search: Search for information")
      expect(result).to include("Use this tool to delegate tasks")
      expect(result).to include("Returns: The agent's findings as a string")
    end
  end
end
