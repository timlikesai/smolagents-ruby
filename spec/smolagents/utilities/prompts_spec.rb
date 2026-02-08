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

    it "returns nil when no managed agents" do
      tools = { "web_search" => search_tool, "final_answer" => final_answer_tool }
      result = described_class.generate_capabilities(tools:)

      expect(result).to be_nil
    end

    it "returns nil when only final_answer tool and no managed agents" do
      tools = { "final_answer" => final_answer_tool }
      result = described_class.generate_capabilities(tools:)

      expect(result).to be_nil
    end

    it "generates sub-agent delegation examples" do
      tools = { "final_answer" => final_answer_tool }
      managed_agents = { "researcher" => managed_agent }

      result = described_class.generate_capabilities(tools:, managed_agents:)

      expect(result).to include("SUB-AGENTS:")
      expect(result).to include("# Researches topics in depth")
      expect(result).to include('researcher(task: "describe what you need")')
    end

    it "handles nil managed_agents" do
      tools = { "web_search" => search_tool, "final_answer" => final_answer_tool }
      result = described_class.generate_capabilities(tools:, managed_agents: nil)

      expect(result).to be_nil
    end
  end

  describe Smolagents::Utilities::Prompts::Agent do
    it "generates agent prompts with Ruby 4.0 identity" do
      result = described_class.generate(tools: [], team: nil, custom: nil)

      expect(result).to include("Ruby 4.0 agent")
      expect(result).to include("```ruby")
      expect(result).to include("final_answer")
      expect(result).to include("TOOL RULES:")
    end

    it "formats tools as YARD-style method stubs" do
      tool = Smolagents::Tools::InlineTool.create(
        :greet,
        "Greet a person",
        name: String
      ) { |name:| "Hello, #{name}!" }

      result = described_class.generate(tools: [tool], team: nil, custom: nil)

      expect(result).to include("# Greet a person")
      expect(result).to include("# @param name [String]")
      expect(result).to include("def greet(name:) = ...")
      expect(result).to include('#   result = greet(name: "Alice")')
    end

    it "uses type-appropriate example values in YARD stubs" do
      tool = Smolagents::Tools::InlineTool.create(
        :add,
        "Add two numbers",
        a: Integer,
        b: Integer
      ) { |a:, b:| a + b }

      result = described_class.generate(tools: [tool], team: nil, custom: nil)

      expect(result).to include("# @param a [Integer]")
      expect(result).to include("def add(a:, b:) = ...")
      expect(result).to include("#   result = add(a: 5, b: 5)")
    end
  end
end
