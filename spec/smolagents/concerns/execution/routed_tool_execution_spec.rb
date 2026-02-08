require "spec_helper"

RSpec.describe Smolagents::Concerns::RoutedToolExecution do
  # Test class that simulates an agent with routed execution
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::RoutedToolExecution
      include Smolagents::Concerns::GenerationTimeout

      attr_accessor :model, :tools, :memory

      def initialize(model:, tools:, dispatcher: nil, router_config: nil)
        @model = model
        @tools = tools
        @memory = Smolagents::Runtime::AgentMemory.new("You are a helpful assistant.")
        initialize_tool_routing(dispatcher_model: dispatcher, router_config:)
      end

      def write_memory_to_messages = @memory.to_messages

      def generation_timeout_seconds = 30
    end
  end

  let(:search_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search for things"
      self.inputs = { query: { type: "string", description: "Query" } }
      self.output_type = "string"
      def execute(query:) = "Results for: #{query}"
    end.new
  end

  let(:final_answer_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "final_answer"
      self.description = "Provide final answer"
      self.inputs = { answer: { type: "string", description: "Answer" } }
      self.output_type = "string"
      def execute(answer:) = answer
    end.new
  end

  let(:tools) { { "search" => search_tool, "final_answer" => final_answer_tool } }

  let(:action_step) do
    Smolagents::Runtime::ActionStepBuilder.new(step_number: 1)
  end

  describe "#execute_native_step" do
    context "without dispatcher (default path)" do
      let(:primary_model) do
        model = build_mock_model
        model.queue_tool_call("search", query: "Ruby")
        model
      end

      let(:executor) { test_class.new(model: primary_model, tools:) }

      it "uses standard NativeToolExecution" do
        executor.execute_native_step(action_step)

        expect(action_step.tool_calls).not_to be_nil
        expect(action_step.observations).to include("search")
        expect(action_step.observations).to include("Results for")
      end
    end

    context "with dispatcher - high confidence" do
      let(:dispatcher) do
        model = build_mock_model
        allow(model).to receive(:model_id).and_return("lfm2.5-1.2b-instruct-mlx")
        model.queue_tool_call("search", query: "Ruby")
        model
      end

      let(:primary_model) do
        model = build_mock_model
        model.queue_tool_call("search", query: "Ruby backup")
        model
      end

      let(:executor) { test_class.new(model: primary_model, tools:, dispatcher:) }

      it "routes through dispatcher" do
        executor.execute_native_step(action_step)

        expect(action_step.tool_calls).not_to be_nil
        expect(action_step.observations).to include("Results for")
      end
    end

    context "with dispatcher - returns no tools" do
      let(:empty_dispatcher) do
        model = build_mock_model
        allow(model).to receive(:model_id).and_return("test-dispatcher")
        model.queue_final_answer("I don't know")
        model
      end

      let(:primary_model) do
        model = build_mock_model
        model.queue_tool_call("search", query: "Ruby")
        model
      end

      let(:executor) { test_class.new(model: primary_model, tools:, dispatcher: empty_dispatcher) }

      it "falls back to primary model" do
        executor.execute_native_step(action_step)

        # Primary should have been called as fallback
        expect(action_step.tool_calls).not_to be_nil
        expect(action_step.observations).to include("Results for")
      end
    end

    context "with dispatcher error" do
      let(:failing_dispatcher) do
        model = instance_double("Smolagents::OpenAIModel")
        allow(model).to receive(:model_id).and_return("failing-model")
        allow(model).to receive(:generate).and_raise(StandardError, "API error")
        model
      end

      let(:primary_model) do
        model = build_mock_model
        model.queue_tool_call("search", query: "Ruby")
        model
      end

      let(:executor) { test_class.new(model: primary_model, tools:, dispatcher: failing_dispatcher) }

      it "falls back to primary model gracefully" do
        executor.execute_native_step(action_step)

        expect(action_step.tool_calls).not_to be_nil
        expect(action_step.observations).to include("Results for")
      end
    end

    context "with final_answer tool" do
      let(:dispatcher) do
        model = build_mock_model
        allow(model).to receive(:model_id).and_return("test-dispatcher")
        model.queue_tool_call("final_answer", answer: "42")
        model
      end

      let(:primary_model) { build_mock_model }
      let(:executor) { test_class.new(model: primary_model, tools:, dispatcher:) }

      it "sets final_answer from tool result" do
        executor.execute_native_step(action_step)

        expect(action_step.final_answer).to eq("42")
      end
    end
  end

  describe "resilience patterns" do
    context "bad tool name from dispatcher" do
      let(:dispatcher) do
        model = build_mock_model
        allow(model).to receive(:model_id).and_return("test-dispatcher")
        model.queue_tool_call("nonexistent_tool")
        model
      end

      let(:primary_model) do
        # Primary is called as fallback when dispatcher returns unknown tool
        # (confidence scoring penalizes unknown tools)
        model = build_mock_model
        model.queue_tool_call("search", query: "fallback")
        model
      end

      let(:executor) { test_class.new(model: primary_model, tools:, dispatcher:) }

      it "falls back to primary when dispatcher returns unknown tool" do
        executor.execute_native_step(action_step)

        # Should fall back to primary and succeed
        expect(action_step.tool_calls).not_to be_nil
        expect(action_step.observations).to include("search")
      end
    end

    context "tool execution failure" do
      let(:failing_tool) do
        Class.new(Smolagents::Tool) do
          self.tool_name = "failing"
          self.description = "A tool that fails"
          self.inputs = {}
          self.output_type = "string"
          def execute = raise StandardError, "Tool crashed"
        end.new
      end

      let(:tools_with_failing) { { "failing" => failing_tool } }

      let(:dispatcher) do
        model = build_mock_model
        allow(model).to receive(:model_id).and_return("test-dispatcher")
        model.queue_tool_call("failing")
        model
      end

      let(:primary_model) { build_mock_model }
      let(:executor) { test_class.new(model: primary_model, tools: tools_with_failing, dispatcher:) }

      it "captures error in observations" do
        executor.execute_native_step(action_step)

        expect(action_step.observations).to include("Error")
        expect(action_step.observations).to include("Tool crashed")
      end
    end
  end
end
