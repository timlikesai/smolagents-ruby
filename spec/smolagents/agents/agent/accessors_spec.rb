require "spec_helper"

RSpec.describe Smolagents::Agents::Agent::Accessors do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:agent) { Smolagents::Agents::Agent.new(model: mock_model, tools: [mock_tool]) }
  let(:mock_executor) { instance_double(Smolagents::RactorExecutor) }
  let(:mock_tool) do
    instance_double(Smolagents::Tool,
                    name: "test_tool",
                    class: Smolagents::FinalAnswerTool,
                    format_for: "def test_tool(value:)\n  # A test tool\nend",
                    inputs: { "value" => { "type" => "string", "description" => "Test input" } },
                    description: "A test tool")
  end

  before do
    allow(mock_executor).to receive(:send_tools)
    allow(Smolagents::RactorExecutor).to receive(:new).and_return(mock_executor)
  end

  describe "accessor methods" do
    describe "#runtime" do
      it "returns the execution runtime" do
        expect(agent.runtime).to be_a(Smolagents::Agents::AgentRuntime)
      end
    end

    describe "#executor" do
      it "returns the code executor" do
        expect(agent.executor).to eq(mock_executor)
      end
    end

    describe "#authorized_imports" do
      it "returns the list of authorized imports" do
        expect(agent.authorized_imports).to be_a(Array)
      end
    end

    describe "#tools" do
      it "returns the tools hash" do
        expect(agent.tools).to be_a(Hash)
        expect(agent.tools.keys).to include("test_tool")
      end
    end

    describe "#model" do
      it "returns the LLM model" do
        expect(agent.model).to eq(mock_model)
      end
    end

    describe "#memory" do
      it "returns the agent memory" do
        expect(agent.memory).to be_a(Smolagents::Runtime::AgentMemory)
      end
    end

    describe "#max_steps" do
      it "returns the maximum steps" do
        expect(agent.max_steps).to be_a(Integer)
      end
    end

    describe "#logger" do
      it "returns the logger" do
        expect(agent.logger).to be_a(Smolagents::Logging::NullLogger)
      end
    end
  end

  describe "#inspect" do
    it "returns a readable representation" do
      inspection = agent.inspect

      expect(inspection).to start_with("#<Agent")
      expect(inspection).to include("model=")
      expect(inspection).to include("tools=")
      expect(inspection).to include("steps=")
    end

    it "shows the model ID" do
      expect(agent.inspect).to include("mock")
    end

    it "includes tool count" do
      expect(agent.inspect).to match(/tools=\[.+\] \(\d+\)/)
    end

    it "shows step count" do
      expect(agent.inspect).to include("steps=0")
    end

    context "with no tools" do
      let(:agent_no_tools) { Smolagents::Agents::Agent.new(model: mock_model, tools: []) }

      it "shows [0] for empty tools" do
        expect(agent_no_tools.inspect).to include("tools=[")
      end
    end

    context "with many tools" do
      let(:many_tools) do
        (1..5).map do |i|
          instance_double(Smolagents::Tool,
                          name: "tool_#{i}",
                          class: Smolagents::FinalAnswerTool,
                          format_for: "def tool_#{i}(v:)\nend",
                          inputs: { "v" => { "type" => "string", "description" => "Input" } },
                          description: "Tool #{i}")
        end
      end

      let(:agent_many_tools) { Smolagents::Agents::Agent.new(model: mock_model, tools: many_tools) }

      it "truncates tool list with ellipsis" do
        expect(agent_many_tools.inspect).to include("...")
      end
    end
  end
end
