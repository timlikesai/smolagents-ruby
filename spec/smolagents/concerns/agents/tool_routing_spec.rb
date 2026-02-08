require "spec_helper"

RSpec.describe Smolagents::Concerns::Agents::ToolRouting do
  # Test class that includes the concern
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Agents::ToolRouting
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer

      attr_accessor :model, :tools

      def initialize(model:, tools:, dispatcher: nil, router_config: nil)
        @model = model
        @tools = tools
        initialize_tool_routing(dispatcher_model: dispatcher, router_config:)
      end
    end
  end

  let(:search_tool) { build_test_tool(name: "search") }
  let(:tools) { { "search" => search_tool } }
  let(:messages) { [Smolagents::ChatMessage.user("Search for Ruby")] }

  # Mock models
  let(:primary_model) do
    model = build_mock_model
    model.queue_tool_call("search", query: "Ruby")
    model
  end

  let(:fast_dispatcher) do
    model = build_mock_model
    allow(model).to receive(:model_id).and_return("functiongemma-270m-it-mlx")
    model.queue_tool_call("search", query: "Ruby")
    model
  end

  describe "#tool_routing_enabled?" do
    context "without dispatcher" do
      let(:routing) { test_class.new(model: primary_model, tools:) }

      it "returns false" do
        expect(routing.tool_routing_enabled?).to be false
      end
    end

    context "with dispatcher" do
      let(:routing) { test_class.new(model: primary_model, tools:, dispatcher: fast_dispatcher) }

      it "returns true" do
        expect(routing.tool_routing_enabled?).to be true
      end
    end
  end

  describe "#route_tool_selection" do
    context "without dispatcher (sensible default)" do
      let(:routing) { test_class.new(model: primary_model, tools:) }

      it "returns nil to signal use primary model" do
        action_step = double("ActionStepBuilder")
        result = routing.route_tool_selection(messages, action_step)

        expect(result).to be_nil
      end
    end

    context "with dispatcher - happy path" do
      let(:routing) { test_class.new(model: primary_model, tools:, dispatcher: fast_dispatcher) }

      it "routes through dispatcher and returns tool calls" do
        action_step = double("ActionStepBuilder", instance_variable_set: nil)
        result = routing.route_tool_selection(messages, action_step)

        expect(result).to be_a(Smolagents::Routing::ToolRouter::RouteResult)
        expect(result.tool_calls).not_to be_empty
      end

      it "records routing metadata in action step" do
        action_step = double("ActionStepBuilder", instance_variable_set: nil)

        expect(action_step).to receive(:instance_variable_set).with(:@routing_source, anything)
        expect(action_step).to receive(:instance_variable_set).with(:@routing_confidence, anything)
        expect(action_step).to receive(:instance_variable_set).with(:@routing_fallback_used, anything)

        routing.route_tool_selection(messages, action_step)
      end
    end

    context "with dispatcher error - graceful fallback" do
      let(:failing_dispatcher) do
        model = instance_double("Smolagents::OpenAIModel")
        allow(model).to receive(:model_id).and_return("failing-model")
        allow(model).to receive(:generate).and_raise(StandardError, "Network timeout")
        model
      end

      let(:routing) { test_class.new(model: primary_model, tools:, dispatcher: failing_dispatcher) }

      it "falls back to primary model and returns result" do
        action_step = double("ActionStepBuilder", instance_variable_set: nil)
        result = routing.route_tool_selection(messages, action_step)

        # Router catches error and falls back to primary
        expect(result).to be_a(Smolagents::Routing::ToolRouter::RouteResult)
        expect(result.source).to eq(:primary)
        expect(result.fallback_used).to be true
      end

      it "indicates fallback was used due to error" do
        action_step = double("ActionStepBuilder", instance_variable_set: nil)
        result = routing.route_tool_selection(messages, action_step)

        # Should have fallback_used = true when error triggered fallback
        expect(result.from_primary?).to be true
        expect(result.fallback_used).to be true
      end
    end
  end

  describe "auto configuration" do
    context "known model (FunctionGemma)" do
      let(:routing) { test_class.new(model: primary_model, tools:, dispatcher: fast_dispatcher) }

      it "uses profile-based thresholds" do
        # FunctionGemma has higher thresholds due to lower accuracy
        config = routing.instance_variable_get(:@tool_router).config
        expect(config.high_confidence_threshold).to eq(0.85)
      end
    end

    context "unknown model" do
      let(:unknown_dispatcher) do
        model = build_mock_model
        allow(model).to receive(:model_id).and_return("unknown-model-xyz")
        model.queue_tool_call("search", query: "test")
        model
      end

      let(:routing) { test_class.new(model: primary_model, tools:, dispatcher: unknown_dispatcher) }

      it "uses conservative defaults" do
        config = routing.instance_variable_get(:@tool_router).config
        expect(config.high_confidence_threshold).to eq(0.9)
      end
    end
  end
end
