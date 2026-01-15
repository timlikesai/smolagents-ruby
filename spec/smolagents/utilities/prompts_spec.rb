require "smolagents"

RSpec.describe Smolagents::Utilities::Prompts do
  describe ".generate_capabilities" do
    let(:search_tool) do
      instance_double(
        Smolagents::Tool,
        name: "web_search",
        description: "Search the web for information",
        inputs: {
          query: { type: "string", description: "The search query" },
          limit: { type: "integer", description: "Maximum results" }
        }
      )
    end

    let(:calculator_tool) do
      instance_double(
        Smolagents::Tool,
        name: "calculate",
        description: "Evaluate mathematical expressions",
        inputs: {
          expression: { type: "string", description: "The math expression to evaluate" }
        }
      )
    end

    let(:final_answer_tool) do
      instance_double(
        Smolagents::Tool,
        name: "final_answer",
        description: "Return the final answer",
        inputs: { answer: { type: "any", description: "The final answer" } }
      )
    end

    let(:managed_agent) do
      instance_double(
        Smolagents::ManagedAgentTool,
        name: "researcher",
        description: "Researches topics in depth"
      )
    end

    describe "for code agents" do
      it "generates tool usage patterns with Ruby code examples" do
        tools = { "web_search" => search_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        expect(result).to include("TOOL USAGE:")
        expect(result).to include("# Search the web for information")
        expect(result).to include("result = web_search(")
        expect(result).to include('query: "your search query"')
      end

      it "generates example arguments based on input types" do
        tools = { "web_search" => search_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        expect(result).to include("limit: 10") # integer with "max" in description
      end

      it "skips final_answer tool in examples" do
        tools = { "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        expect(result).to be_empty
      end

      it "generates sub-agent delegation examples" do
        tools = { "final_answer" => final_answer_tool }
        managed_agents = { "researcher" => managed_agent }

        result = described_class.generate_capabilities(tools:, managed_agents:, agent_type: :code)

        expect(result).to include("SUB-AGENTS:")
        expect(result).to include("# Researches topics in depth")
        expect(result).to include('researcher(task: "describe what you need")')
      end

      it "limits tool examples to 3" do
        tools = {
          "tool1" => search_tool,
          "tool2" => calculator_tool,
          "tool3" => search_tool,
          "tool4" => calculator_tool,
          "final_answer" => final_answer_tool
        }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        # Should only have 3 tool examples (not 4)
        expect(result.scan("result = ").count).to eq(3)
      end
    end

    describe "for base agents" do
      it "generates tool usage with Ruby method calls" do
        tools = { "web_search" => search_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :tool)

        expect(result).to include("TOOL USAGE:")
        expect(result).to include("web_search(")
        # Base agents don't wrap in "result = "
        expect(result).not_to include("result = web_search")
      end

      it "generates sub-agent delegation examples with Ruby syntax" do
        tools = { "final_answer" => final_answer_tool }
        managed_agents = { "researcher" => managed_agent }

        result = described_class.generate_capabilities(tools:, managed_agents:, agent_type: :tool)

        expect(result).to include("SUB-AGENTS:")
        expect(result).to include('researcher(task: "describe what you need")')
      end
    end

    describe "example value inference" do
      let(:url_tool) do
        instance_double(
          Smolagents::Tool,
          name: "visit_url",
          description: "Visit a URL",
          inputs: { url: { type: "string", description: "The URL to visit" } }
        )
      end

      let(:file_tool) do
        instance_double(
          Smolagents::Tool,
          name: "read_file",
          description: "Read a file",
          inputs: { path: { type: "string", description: "Path to the file" } }
        )
      end

      let(:bool_tool) do
        instance_double(
          Smolagents::Tool,
          name: "toggle",
          description: "Toggle a setting",
          inputs: { enabled: { type: "boolean", description: "Enable the feature" } }
        )
      end

      it "infers URL examples from description" do
        tools = { "visit_url" => url_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        expect(result).to include("https://example.com")
      end

      it "infers file path examples from description" do
        tools = { "read_file" => file_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        expect(result).to include("/path/to/file")
      end

      it "uses true for boolean types" do
        tools = { "toggle" => bool_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)

        expect(result).to include("enabled: true")
      end
    end

    describe "edge cases" do
      it "returns empty string when no tools and no managed agents" do
        result = described_class.generate_capabilities(tools: {}, agent_type: :code)
        expect(result).to be_empty
      end

      it "returns empty string when only final_answer tool present" do
        tools = { "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, agent_type: :code)
        expect(result).to be_empty
      end

      it "handles nil managed_agents" do
        tools = { "web_search" => search_tool, "final_answer" => final_answer_tool }
        result = described_class.generate_capabilities(tools:, managed_agents: nil, agent_type: :code)

        expect(result).to include("TOOL USAGE:")
        expect(result).not_to include("SUB-AGENTS:")
      end
    end
  end

  describe Smolagents::Utilities::Prompts::CodeAgent do
    it "generates complete code agent prompts" do
      result = described_class.generate(tools: [], team: nil, custom: nil)

      expect(result).to include("You solve tasks by writing Ruby code")
      expect(result).to include("Thought:")
      expect(result).to include("```ruby")
      expect(result).to include("final_answer")
    end
  end

  describe Smolagents::Utilities::Prompts::Agent do
    it "generates base agent prompts with Ruby method calls" do
      result = described_class.generate(tools: [], team: nil, custom: nil)

      expect(result).to include("You solve tasks by calling tools")
      expect(result).to include("tool_name(arg:")
      expect(result).to include("final_answer")
    end
  end
end
