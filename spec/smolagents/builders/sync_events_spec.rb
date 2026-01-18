RSpec.describe Smolagents::Builders::AgentBuilder do
  let(:mock_model) { Smolagents::Testing::MockModel.new }

  describe "#sync_events" do
    it "defaults to false" do
      builder = Smolagents.agent.model { mock_model }
      expect(builder.config[:sync_events]).to be false
    end

    it "enables sync_events when called" do
      builder = Smolagents.agent.model { mock_model }.sync_events
      expect(builder.config[:sync_events]).to be true
    end

    it "accepts explicit boolean" do
      builder = Smolagents.agent.model { mock_model }.sync_events(enabled: false)
      expect(builder.config[:sync_events]).to be false
    end

    it "passes through to AgentConfig" do
      mock_model.queue_final_answer("done")
      agent = Smolagents.agent.model { mock_model }.sync_events.build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "sync event emission" do
    it "fires handlers immediately with sync_events enabled" do
      mock_model.queue_final_answer("done")
      handler_calls = []

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .sync_events
                        .on(:step_complete) { |e| handler_calls << e }
                        .build

      agent.run("Test task")

      # With sync_events, handlers should have fired immediately
      expect(handler_calls).not_to be_empty
      expect(handler_calls.first).to be_a(Smolagents::Events::StepCompleted)
    end

    it "emits ToolCallCompleted events for tool calls" do
      mock_model.queue_code_action("final_answer(answer: simple_tool(value: 5))")

      simple_tool = Smolagents::Tools.define_tool(
        "simple_tool",
        description: "A simple tool",
        inputs: { value: { type: "integer", description: "A value" } },
        output_type: "integer"
      ) { |value:| value * 2 }

      tool_events = []

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(simple_tool)
                        .sync_events
                        .on(:tool_complete) { |e| tool_events << e }
                        .build

      agent.run("Test task")

      # Should have tool complete events for simple_tool and final_answer
      expect(tool_events.size).to be >= 1
      tool_names = tool_events.map(&:tool_name)
      expect(tool_names).to include("simple_tool")
    end
  end
end
