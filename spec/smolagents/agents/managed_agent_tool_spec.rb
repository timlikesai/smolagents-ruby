RSpec.describe Smolagents::ManagedAgentTool do
  # Create a simple mock agent
  let(:mock_agent_class) do
    Class.new do
      attr_reader :tools

      def initialize
        @tools = { "search" => Object.new, "calculator" => Object.new }
      end

      def run(_prompt, reset: true)
        Smolagents::RunResult.new(
          output: "Agent completed task",
          state: :success,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      end

      def self.name
        "MockAgent"
      end
    end
  end

  let(:mock_agent) { mock_agent_class.new }
  let(:managed_tool) { described_class.new(agent: mock_agent) }

  describe "#initialize" do
    it "creates a tool from an agent" do
      expect(managed_tool).to be_a(Smolagents::Tool)
    end

    it "derives tool name from agent class name" do
      expect(managed_tool.tool_name).to eq("mock_agent")
    end

    it "allows custom tool name" do
      custom_tool = described_class.new(agent: mock_agent, name: "custom_name")
      expect(custom_tool.tool_name).to eq("custom_name")
    end

    it "derives description from agent's tools" do
      expect(managed_tool.description).to include("search")
      expect(managed_tool.description).to include("calculator")
    end

    it "allows custom description" do
      custom_tool = described_class.new(agent: mock_agent, description: "Custom description")
      expect(custom_tool.description).to eq("Custom description")
    end
  end

  describe "tool attributes" do
    it "has correct tool_name" do
      expect(managed_tool.tool_name).to eq("mock_agent")
      expect(managed_tool.name).to eq("mock_agent")
    end

    it "has correct description" do
      expect(managed_tool.description).to be_a(String)
      expect(managed_tool.description).to include("specialized agent")
    end

    it "has correct inputs" do
      expect(managed_tool.inputs).to be_a(Hash)
      expect(managed_tool.inputs).to have_key("task")
      expect(managed_tool.inputs["task"][:type]).to eq("string")
      expect(managed_tool.inputs["task"][:description]).to include("mock_agent")
    end

    it "has correct output_type" do
      expect(managed_tool.output_type).to eq("string")
    end

    it "has nil output_schema" do
      expect(managed_tool.output_schema).to be_nil
    end
  end

  describe "#to_h" do
    it "converts to hash with dynamic attributes" do
      hash = managed_tool.to_h
      expect(hash[:name]).to eq("mock_agent")
      expect(hash[:description]).to be_a(String)
      expect(hash[:inputs]).to have_key("task")
      expect(hash[:output_type]).to eq("string")
    end
  end

  describe "#to_code_prompt" do
    it "generates code prompt with dynamic attributes" do
      prompt = managed_tool.to_code_prompt
      expect(prompt).to include("def mock_agent")
      expect(prompt).to include("task: string")
    end
  end

  describe "#to_tool_calling_prompt" do
    it "generates tool calling prompt with agent name" do
      prompt = managed_tool.to_tool_calling_prompt
      expect(prompt).to include("mock_agent:")
      expect(prompt).to include("delegate tasks")
      expect(prompt).to include("mock_agent")
    end
  end

  describe "#forward" do
    it "delegates to the wrapped agent" do
      expect(mock_agent).to receive(:run).with(
        anything,
        reset: true
      ).and_return(
        Smolagents::RunResult.new(
          output: "Success",
          state: :success,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      )

      result = managed_tool.forward(task: "Test task")
      expect(result).to eq("Success")
    end

    it "handles agent failures" do
      allow(mock_agent).to receive(:run).and_return(
        Smolagents::RunResult.new(
          output: nil,
          state: :error,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      )

      result = managed_tool.forward(task: "Test task")
      expect(result).to include("failed")
      expect(result).to include("error")
    end

    it "includes agent name in the prompt" do
      expect(mock_agent).to receive(:run).with(
        a_string_including("mock_agent"),
        reset: true
      ).and_return(
        Smolagents::RunResult.new(
          output: "Done",
          state: :success,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      )

      managed_tool.forward(task: "Test task")
    end

    it "includes the task in the prompt" do
      expect(mock_agent).to receive(:run).with(
        a_string_including("Specific test task"),
        reset: true
      ).and_return(
        Smolagents::RunResult.new(
          output: "Done",
          state: :success,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      )

      managed_tool.forward(task: "Specific test task")
    end
  end

  describe "#call" do
    it "works like a normal tool" do
      result = managed_tool.call(task: "Test task")
      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.tool_name).to eq("mock_agent")
    end

    it "includes metadata" do
      result = managed_tool.call(task: "Test task")
      expect(result.metadata[:inputs]).to eq({ task: "Test task" })
      expect(result.metadata[:output_type]).to eq("string")
    end
  end

  describe "multiple instances" do
    it "maintains independent attributes" do
      tool1 = described_class.new(agent: mock_agent, name: "agent1")
      tool2 = described_class.new(agent: mock_agent, name: "agent2")

      expect(tool1.tool_name).to eq("agent1")
      expect(tool2.tool_name).to eq("agent2")
      expect(tool1.inputs["task"][:description]).to include("agent1")
      expect(tool2.inputs["task"][:description]).to include("agent2")
    end

    it "does not share state between instances" do
      tool1 = described_class.new(agent: mock_agent, name: "first")
      expect(tool1.tool_name).to eq("first")

      tool2 = described_class.new(agent: mock_agent, name: "second")
      expect(tool2.tool_name).to eq("second")

      # Verify first tool is unchanged
      expect(tool1.tool_name).to eq("first")
    end
  end
end
