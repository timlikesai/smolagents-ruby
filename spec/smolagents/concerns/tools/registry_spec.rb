require "spec_helper"

RSpec.describe Smolagents::Concerns::Tools::Registry do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Tools::Registry

      def initialize(tools = {})
        @tools = tools
      end
    end
  end
  let(:search_tool) do
    MockTool.new(
      name: "search",
      description: "Search the web for information. Returns relevant results.",
      category: :search
    )
  end
  let(:final_answer_tool) do
    MockTool.new(
      name: "final_answer",
      description: "Provide the final answer to the user.",
      category: nil
    )
  end
  let(:calculator_tool) do
    MockTool.new(
      name: "calculator",
      description: "Perform mathematical calculations.",
      category: :math
    )
  end
  let(:tools) do
    {
      "search" => search_tool,
      "final_answer" => final_answer_tool,
      "calculator" => calculator_tool
    }
  end
  let(:registry) { test_class.new(tools) }
  let(:empty_registry) { test_class.new({}) }

  # Simple struct to act as a mock tool
  MockTool = Data.define(:name, :description, :category) do
    def format_for(_format) = { name:, description: }
  end

  describe "tool access" do
    describe "#find_tool" do
      it "finds tool by string name" do
        expect(registry.find_tool("search")).to eq(search_tool)
      end

      it "finds tool by symbol name" do
        expect(registry.find_tool(:search)).to eq(search_tool)
      end

      it "returns nil for unknown tool" do
        expect(registry.find_tool("unknown")).to be_nil
      end
    end

    describe "#tool_exists?" do
      it "returns true for existing tool (string)" do
        expect(registry.tool_exists?("search")).to be true
      end

      it "returns true for existing tool (symbol)" do
        expect(registry.tool_exists?(:final_answer)).to be true
      end

      it "returns false for unknown tool" do
        expect(registry.tool_exists?("unknown")).to be false
      end
    end

    describe "#tool_count" do
      it "returns the number of tools" do
        expect(registry.tool_count).to eq(3)
      end

      it "returns 0 for empty registry" do
        expect(empty_registry.tool_count).to eq(0)
      end
    end

    describe "#tool_names" do
      it "returns all tool names" do
        expect(registry.tool_names).to contain_exactly("search", "final_answer", "calculator")
      end

      it "returns empty array for empty registry" do
        expect(empty_registry.tool_names).to eq([])
      end
    end

    describe "#tool_values" do
      it "returns all tool instances" do
        expect(registry.tool_values).to contain_exactly(search_tool, final_answer_tool, calculator_tool)
      end

      it "returns empty array for empty registry" do
        expect(empty_registry.tool_values).to eq([])
      end
    end
  end

  describe "tool formatting" do
    describe "#tool_descriptions" do
      it "formats tools as bullet points with descriptions" do
        result = registry.tool_descriptions
        expect(result).to include("- search: Search the web for information")
        expect(result).to include("- final_answer: Provide the final answer")
        expect(result).to include("- calculator: Perform mathematical calculations")
      end

      it "returns empty string for empty registry" do
        expect(empty_registry.tool_descriptions).to eq("")
      end
    end

    describe "#tool_list_brief" do
      it "formats tools with first sentence only" do
        result = registry.tool_list_brief
        expect(result).to include("search: Search the web for information")
        expect(result).to include("final_answer: Provide the final answer to the user")
        expect(result).not_to include("Returns relevant results")
      end

      it "returns empty string for empty registry" do
        expect(empty_registry.tool_list_brief).to eq("")
      end
    end

    describe "#format_tools_for" do
      it "formats tools for model consumption" do
        result = registry.format_tools_for(:tool_calling)
        expect(result).to have_attributes(count: 3)
        expect(result).to all(be_a(Hash))
      end

      it "passes format to each tool" do
        result = registry.format_tools_for(:tool_calling)
        expect(result.map { |t| t[:name] }).to contain_exactly("search", "final_answer", "calculator")
      end

      it "returns empty array for empty registry" do
        expect(empty_registry.format_tools_for(:tool_calling)).to eq([])
      end
    end
  end

  describe "tool filtering" do
    describe "#select_tools" do
      it "returns all tools when no filter provided" do
        result = registry.select_tools
        expect(result).to contain_exactly(search_tool, final_answer_tool, calculator_tool)
      end

      it "filters by specific keys" do
        result = registry.select_tools(keys: %w[search calculator])
        expect(result).to contain_exactly(search_tool, calculator_tool)
      end

      it "accepts symbol keys" do
        result = registry.select_tools(keys: %i[search])
        expect(result).to contain_exactly(search_tool)
      end

      it "excludes specified tools" do
        result = registry.select_tools(exclude: ["final_answer"])
        expect(result).to contain_exactly(search_tool, calculator_tool)
      end

      it "combines keys and exclude" do
        result = registry.select_tools(keys: %w[search final_answer], exclude: ["search"])
        expect(result).to contain_exactly(final_answer_tool)
      end

      it "returns empty array when keys dont match" do
        result = registry.select_tools(keys: ["unknown"])
        expect(result).to eq([])
      end
    end

    describe "#find_tools_by_pattern" do
      it "finds tools matching string pattern" do
        result = registry.find_tools_by_pattern("search")
        expect(result).to contain_exactly("search")
      end

      it "finds tools matching regex pattern" do
        result = registry.find_tools_by_pattern(/^(search|calculator)$/)
        expect(result).to contain_exactly("search", "calculator")
      end

      it "finds partial matches" do
        result = registry.find_tools_by_pattern("_")
        expect(result).to contain_exactly("final_answer")
      end

      it "returns empty array for no matches" do
        result = registry.find_tools_by_pattern("xyz")
        expect(result).to eq([])
      end
    end
  end

  describe "self-documentation" do
    describe "#tools_summary" do
      it "returns a summary hash" do
        summary = registry.tools_summary
        expect(summary).to be_a(Hash)
        expect(summary[:count]).to eq(3)
        expect(summary[:names]).to contain_exactly("search", "final_answer", "calculator")
        expect(summary[:by_category]).to be_a(Hash)
      end

      it "returns zeros for empty registry" do
        summary = empty_registry.tools_summary
        expect(summary[:count]).to eq(0)
        expect(summary[:names]).to eq([])
      end
    end

    describe "#tools_by_category" do
      it "groups tools by category" do
        result = registry.tools_by_category
        expect(result[:search]).to contain_exactly("search")
        expect(result[:math]).to contain_exactly("calculator")
        expect(result[:uncategorized]).to contain_exactly("final_answer")
      end

      it "returns empty hash for empty registry" do
        expect(empty_registry.tools_by_category).to eq({})
      end
    end
  end

  describe "class methods" do
    describe ".registry_methods" do
      it "returns method documentation" do
        methods = test_class.registry_methods
        expect(methods).to be_a(Hash)
        expect(methods[:access]).to include(:find_tool, :tool_exists?, :tool_count)
        expect(methods[:formatting]).to include(:tool_descriptions, :format_tools_for)
        expect(methods[:filtering]).to include(:select_tools, :find_tools_by_pattern)
        expect(methods[:introspection]).to include(:tools_summary, :tools_by_category)
      end
    end
  end

  describe "#tools reader" do
    it "exposes the tools hash" do
      expect(registry.tools).to eq(tools)
    end
  end
end
