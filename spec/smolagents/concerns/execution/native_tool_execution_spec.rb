RSpec.describe Smolagents::Concerns::NativeToolExecution do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::NativeToolExecution

      attr_accessor :model, :tools

      def write_memory_to_messages = []
    end
  end

  let(:instance) { test_class.new }
  let(:action_step) { Smolagents::Runtime::ActionStepBuilder.new(step_number: 0) }

  let(:mock_tool) do
    tool = build_test_tool(name: "calculator")
    allow(tool).to receive(:call).and_return("42")
    tool
  end

  before do
    instance.tools = { "calculator" => mock_tool }
  end

  describe "#execute_native_step" do
    context "when model returns tool calls" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(name: "calculator", arguments: { expression: "6*7" }, id: "call_1")
      end

      let(:response) do
        Smolagents::Types::ChatMessage.assistant(nil, tool_calls: [tool_call])
      end

      before do
        model = instance_double(Smolagents::Models::Model, generate: response)
        instance.model = model
      end

      it "executes the tool and stores observations" do
        instance.execute_native_step(action_step)

        expect(action_step.tool_calls).to eq([tool_call])
        expect(action_step.observations).to include("calculator: 42")
      end
    end

    context "when model returns text (final answer)" do
      let(:response) do
        Smolagents::Types::ChatMessage.assistant("The answer is 42")
      end

      before do
        model = instance_double(Smolagents::Models::Model, generate: response)
        instance.model = model
      end

      it "treats text as final answer" do
        instance.execute_native_step(action_step)

        expect(action_step.final_answer).to eq("The answer is 42")
        expect(action_step.observations).to eq("The answer is 42")
      end
    end

    context "when final_answer tool is called" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(name: "final_answer", arguments: { answer: "42" }, id: "call_2")
      end

      let(:response) do
        Smolagents::Types::ChatMessage.assistant(nil, tool_calls: [tool_call])
      end

      before do
        final_tool = build_test_tool(name: "final_answer")
        allow(final_tool).to receive(:call).and_return("42")
        instance.tools["final_answer"] = final_tool
        model = instance_double(Smolagents::Models::Model, generate: response)
        instance.model = model
      end

      it "extracts the final answer" do
        instance.execute_native_step(action_step)

        expect(action_step.final_answer).to eq("42")
      end
    end

    context "when tool raises an error" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(name: "calculator", arguments: { expression: "bad" }, id: "call_3")
      end

      let(:response) do
        Smolagents::Types::ChatMessage.assistant(nil, tool_calls: [tool_call])
      end

      before do
        allow(mock_tool).to receive(:call).and_raise(RuntimeError, "divide by zero")
        model = instance_double(Smolagents::Models::Model, generate: response)
        instance.model = model
      end

      it "captures the error in observations" do
        instance.execute_native_step(action_step)

        expect(action_step.observations).to include("Error: divide by zero")
      end
    end

    context "when tool is unknown" do
      let(:tool_call) do
        Smolagents::Types::ToolCall.new(name: "nonexistent", arguments: {}, id: "call_4")
      end

      let(:response) do
        Smolagents::Types::ChatMessage.assistant(nil, tool_calls: [tool_call])
      end

      before do
        model = instance_double(Smolagents::Models::Model, generate: response)
        instance.model = model
      end

      it "reports unknown tool error" do
        instance.execute_native_step(action_step)

        expect(action_step.observations).to include("Error: unknown tool 'nonexistent'")
      end
    end
  end
end
