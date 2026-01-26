require "spec_helper"

RSpec.describe Smolagents::Models::Model::Eventing do
  let(:queue) { Thread::Queue.new }

  let(:test_model_class) do
    Class.new(Smolagents::Model) do
      def generate(messages, **options)
        with_generate_events(messages, options) do
          token_usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
          Smolagents::ChatMessage.assistant("response", token_usage:)
        end
      end
    end
  end

  let(:model) { test_model_class.new(model_id: "test-model", temperature: 0.5) }

  after { Smolagents::Events::AsyncQueue.reset! }

  describe "#with_generate_events" do
    context "when not connected to queue" do
      it "does not emit events" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        expect(queue.size).to eq(0)
      end

      it "returns the generated result" do
        result = model.generate([Smolagents::ChatMessage.user("hello")])
        expect(result.content).to eq("response")
      end
    end

    context "when connected to queue" do
      before { model.connect_to(queue) }

      it "emits ModelGenerateRequested event" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateRequested) }

        expect(requested).not_to be_nil
        expect(requested.model_id).to eq("test-model")
        expect(requested.message_count).to eq(1)
        expect(requested.has_tools).to be false
      end

      it "emits ModelGenerateCompleted event" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        events = drain_queue(queue)
        completed = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateCompleted) }

        expect(completed).not_to be_nil
        expect(completed.model_id).to eq("test-model")
        expect(completed.outcome).to eq(:success)
        expect(completed.duration_ms).to be_a(Integer)
      end

      it "includes token_usage in completed event" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        events = drain_queue(queue)
        completed = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateCompleted) }

        expect(completed.token_usage).to include(input_tokens: 10, output_tokens: 20)
      end

      it "includes temperature in requested event" do
        model.generate([Smolagents::ChatMessage.user("hello")], temperature: 0.9)
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateRequested) }

        expect(requested.temperature).to eq(0.9)
      end

      it "uses default temperature when not overridden" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateRequested) }

        expect(requested.temperature).to eq(0.5)
      end

      it "detects when tools are provided" do
        model.generate([Smolagents::ChatMessage.user("hello")], tools_to_call_from: [:some_tool])
        events = drain_queue(queue)
        requested = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateRequested) }

        expect(requested.has_tools).to be true
      end
    end

    context "when response contains tool calls" do
      let(:tool_call_model_class) do
        Class.new(Smolagents::Model) do
          def generate(messages, **options)
            with_generate_events(messages, options) do
              tool_calls = [
                Smolagents::ToolCall.new(id: "call_123", name: "search", arguments: { query: "test" }),
                Smolagents::ToolCall.new(id: "call_456", name: "calculate", arguments: { expr: "1+1" })
              ]
              token_usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 20)
              Smolagents::ChatMessage.assistant("", tool_calls:, token_usage:)
            end
          end
        end
      end

      let(:tool_model) { tool_call_model_class.new(model_id: "tool-model") }

      before { tool_model.connect_to(queue) }

      it "emits ToolCallParsed event for each tool call" do
        tool_model.generate([Smolagents::ChatMessage.user("search for test")])
        events = drain_queue(queue)
        parsed_events = events.select { |e| e.is_a?(Smolagents::Events::ToolCallParsed) }

        expect(parsed_events.size).to eq(2)
      end

      it "includes tool call details in parsed event" do
        tool_model.generate([Smolagents::ChatMessage.user("search for test")])
        events = drain_queue(queue)
        search_event = events.find do |e|
          e.is_a?(Smolagents::Events::ToolCallParsed) && e.tool_name == "search"
        end

        expect(search_event.model_id).to eq("tool-model")
        expect(search_event.call_id).to eq("call_123")
        expect(search_event.arguments).to eq({ query: "test" })
      end

      it "freezes arguments in parsed event" do
        tool_model.generate([Smolagents::ChatMessage.user("search for test")])
        events = drain_queue(queue)
        parsed_event = events.find { |e| e.is_a?(Smolagents::Events::ToolCallParsed) }

        expect(parsed_event.arguments).to be_frozen
      end

      it "emits events in order: requested, parsed, completed" do
        tool_model.generate([Smolagents::ChatMessage.user("search for test")])
        events = drain_queue(queue)
        event_types = events.map(&:class)

        requested_idx = event_types.index(Smolagents::Events::ModelGenerateRequested)
        parsed_idx = event_types.index(Smolagents::Events::ToolCallParsed)
        completed_idx = event_types.index(Smolagents::Events::ModelGenerateCompleted)

        expect(requested_idx).to be < parsed_idx
        expect(parsed_idx).to be < completed_idx
      end

      it "sets has_tool_calls in completed event" do
        tool_model.generate([Smolagents::ChatMessage.user("search for test")])
        events = drain_queue(queue)
        completed = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateCompleted) }

        expect(completed.has_tool_calls).to be true
      end
    end

    context "when response has no tool calls" do
      before { model.connect_to(queue) }

      it "does not emit ToolCallParsed events" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        events = drain_queue(queue)
        parsed_events = events.select { |e| e.is_a?(Smolagents::Events::ToolCallParsed) }

        expect(parsed_events).to be_empty
      end

      it "sets has_tool_calls to false in completed event" do
        model.generate([Smolagents::ChatMessage.user("hello")])
        events = drain_queue(queue)
        completed = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateCompleted) }

        expect(completed.has_tool_calls).to be false
      end
    end

    context "when generation raises an error" do
      let(:error_model_class) do
        Class.new(Smolagents::Model) do
          def generate(messages, **options)
            with_generate_events(messages, options) do
              raise StandardError, "API error"
            end
          end
        end
      end

      let(:error_model) { error_model_class.new(model_id: "error-model") }

      before { error_model.connect_to(queue) }

      it "emits completed event with error outcome" do
        expect { error_model.generate([Smolagents::ChatMessage.user("fail")]) }
          .to raise_error(StandardError, "API error")

        events = drain_queue(queue)
        completed = events.find { |e| e.is_a?(Smolagents::Events::ModelGenerateCompleted) }

        expect(completed.outcome).to eq(:error)
      end

      it "re-raises the original error" do
        expect { error_model.generate([Smolagents::ChatMessage.user("fail")]) }
          .to raise_error(StandardError, "API error")
      end
    end
  end

  describe "#emitting?" do
    it "returns false when not connected" do
      expect(model.emitting?).to be false
    end

    it "returns true when connected" do
      model.connect_to(queue)
      expect(model.emitting?).to be true
    end
  end

  def drain_queue(event_queue)
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end
end
