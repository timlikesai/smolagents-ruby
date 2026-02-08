require "spec_helper"

RSpec.describe Smolagents::Routing::ToolRouter do
  let(:search_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search for things"
      self.inputs = { query: { type: "string", description: "Search query" } }
      self.output_type = "string"
      def execute(query:) = "results for #{query}"
    end.new
  end

  let(:tools) { { "search" => search_tool } }
  let(:messages) { [Smolagents::ChatMessage.user("Search for Ruby")] }

  # Mock models
  let(:dispatcher) do
    model = instance_double(Smolagents::OpenAIModel)
    msg = Smolagents::ChatMessage.assistant("")
    msg_with_calls = msg.with(tool_calls: [Smolagents::Types::ToolCall.new(name: "search",
                                                                           arguments: { "query" => "Ruby" }, id: "1")])
    allow(model).to receive_messages(model_id: "test-dispatcher", generate: msg_with_calls)
    model
  end

  let(:primary) do
    model = instance_double(Smolagents::OpenAIModel)
    msg = Smolagents::ChatMessage.assistant("")
    msg_with_calls = msg.with(tool_calls: [Smolagents::Types::ToolCall.new(name: "search",
                                                                           arguments: { "query" => "Ruby 4.0" }, id: "2")])
    allow(model).to receive_messages(model_id: "test-primary", generate: msg_with_calls)
    model
  end

  describe "initialization" do
    it "works with dispatcher and primary" do
      router = described_class.new(dispatcher:, primary:, tools:)

      expect(router.dispatcher).to eq(dispatcher)
      expect(router.primary).to eq(primary)
      expect(router.use_dispatcher?).to be true
    end

    it "works with primary only" do
      router = described_class.new(primary:, tools:)

      expect(router.dispatcher).to be_nil
      expect(router.use_dispatcher?).to be false
    end

    it "accepts custom config" do
      config = Smolagents::Types::ToolRouterConfig.aggressive("test")
      router = described_class.new(primary:, tools:, config:)

      expect(router.config.high_confidence_threshold).to eq(0.6)
    end

    it "uses default threshold strategy" do
      router = described_class.new(primary:, tools:)

      expect(router.strategy).to be_a(Smolagents::Routing::Strategies::Threshold)
    end

    it "accepts custom strategy" do
      strategy = Smolagents::Routing::Strategies::CostAware.new
      router = described_class.new(primary:, tools:, strategy:)

      expect(router.strategy).to eq(strategy)
    end

    it "configures default strategy from config thresholds" do
      config = Smolagents::Types::ToolRouterConfig.aggressive("test")
      router = described_class.new(primary:, tools:, config:)

      expect(router.strategy.high_threshold).to eq(0.6)
      expect(router.strategy.low_threshold).to eq(0.3)
    end
  end

  describe "#route" do
    context "without dispatcher" do
      let(:router) { described_class.new(primary:, tools:) }

      it "routes directly to primary" do
        result = router.route(messages)

        expect(result.from_primary?).to be true
        expect(result.tool_calls).not_to be_empty
        expect(result.confidence).to eq(1.0)
      end
    end

    context "with dispatcher - high confidence" do
      let(:config) do
        Smolagents::Types::ToolRouterConfig.new(
          enabled: true,
          model_id: "test-dispatcher",
          high_confidence_threshold: 0.7, # Lower than default for test
          low_confidence_threshold: 0.3,
          max_parallel_calls: 3,
          fallback_on_error: true,
          collect_traces: false
        )
      end

      let(:router) { described_class.new(dispatcher:, primary:, tools:, config:) }

      it "uses dispatcher result when high confidence" do
        result = router.route(messages)

        expect(result.from_dispatcher?).to be true
        expect(result.tool_calls.first.name).to eq("search")
        expect(result.fallback_used).to be false
      end
    end

    context "with dispatcher - low confidence (unknown tool)" do
      let(:low_confidence_dispatcher) do
        model = instance_double(Smolagents::OpenAIModel)
        msg = Smolagents::ChatMessage.assistant("")
        msg_with_calls = msg.with(tool_calls: [Smolagents::Types::ToolCall.new(name: "unknown_tool", arguments: {},
                                                                               id: "1")])
        allow(model).to receive_messages(model_id: "test-dispatcher", generate: msg_with_calls)
        model
      end

      let(:router) { described_class.new(dispatcher: low_confidence_dispatcher, primary:, tools:) }

      it "falls back to primary for low confidence" do
        result = router.route(messages)

        # Unknown tool tanks confidence, should delegate
        expect(result.from_primary?).to be true
        expect(result.fallback_used).to be true
      end
    end

    context "with dispatcher - error handling" do
      let(:failing_dispatcher) do
        model = instance_double(Smolagents::OpenAIModel)
        allow(model).to receive(:model_id).and_return("test-dispatcher")
        allow(model).to receive(:generate).and_raise(StandardError, "API timeout")
        model
      end

      let(:config) { Smolagents::Types::ToolRouterConfig.with_model("test", collect_traces: false) }
      let(:router) { described_class.new(dispatcher: failing_dispatcher, primary:, tools:, config:) }

      it "falls back to primary on dispatcher error" do
        result = router.route(messages)

        expect(result.from_primary?).to be true
      end
    end

    context "with dispatcher - no tool calls" do
      let(:empty_dispatcher) do
        model = instance_double(Smolagents::OpenAIModel)
        msg = Smolagents::ChatMessage.assistant("I don't know")
        allow(model).to receive_messages(model_id: "test-dispatcher", generate: msg)
        model
      end

      let(:router) { described_class.new(dispatcher: empty_dispatcher, primary:, tools:) }

      it "falls back to primary when no tools returned" do
        result = router.route(messages)

        expect(result.from_primary?).to be true
      end
    end
  end

  describe "RouteResult" do
    let(:tool_call) { Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1") }

    it "provides source predicates" do
      result = described_class::RouteResult.new(
        tool_calls: [tool_call],
        source: :dispatcher,
        confidence: 0.85,
        latency_ms: 100,
        fallback_used: false,
        trace_id: nil
      )

      expect(result.from_dispatcher?).to be true
      expect(result.from_primary?).to be false
      expect(result.high_confidence?).to be true
    end
  end

  describe "custom strategy routing" do
    let(:config) do
      Smolagents::Types::ToolRouterConfig.new(
        enabled: true,
        model_id: "test-dispatcher",
        high_confidence_threshold: 0.8,
        low_confidence_threshold: 0.5,
        max_parallel_calls: 3,
        fallback_on_error: true,
        collect_traces: false
      )
    end

    context "with always-execute strategy" do
      let(:always_execute_strategy) do
        strategy = instance_double(RoutingStrategy)
        allow(strategy).to receive(:route).and_return(:execute_directly)
        strategy
      end

      let(:router) do
        described_class.new(dispatcher:, primary:, tools:, config:, strategy: always_execute_strategy)
      end

      it "uses dispatcher result regardless of confidence" do
        result = router.route(messages)

        expect(result.from_dispatcher?).to be true
        expect(result.fallback_used).to be false
      end
    end

    context "with always-delegate strategy" do
      let(:always_delegate_strategy) do
        strategy = instance_double(RoutingStrategy)
        allow(strategy).to receive(:route).and_return(:delegate_to_primary)
        strategy
      end

      let(:router) do
        described_class.new(dispatcher:, primary:, tools:, config:, strategy: always_delegate_strategy)
      end

      it "uses primary result regardless of confidence" do
        result = router.route(messages)

        expect(result.from_primary?).to be true
        expect(result.fallback_used).to be true
      end
    end

    context "with always-validate strategy" do
      let(:always_validate_strategy) do
        strategy = instance_double(RoutingStrategy)
        allow(strategy).to receive(:route).and_return(:validate_with_primary)
        strategy
      end

      let(:router) do
        described_class.new(dispatcher:, primary:, tools:, config:, strategy: always_validate_strategy)
      end

      it "validates with primary" do
        router.route(messages)

        # Primary is called for validation
        expect(primary).to have_received(:generate)
      end
    end

    context "with cost-aware strategy" do
      let(:cost_strategy) { Smolagents::Routing::Strategies::CostAware.new }

      let(:router) do
        described_class.new(dispatcher:, primary:, tools:, config:, strategy: cost_strategy)
      end

      it "works with real strategy implementation" do
        result = router.route(messages)

        # Without budget context, falls back to threshold behavior
        # High confidence tool should execute directly
        expect(result).to be_a(described_class::RouteResult)
      end
    end
  end
end
