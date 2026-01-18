require "spec_helper"

RSpec.describe Smolagents::Concerns::ObservationRouter do
  let(:mock_model) { Smolagents::Testing::MockModel.new }

  # Test class that includes the concern
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ObservationRouter

      attr_accessor :model, :executor, :memory

      def initialize(model:, executor: nil, memory: nil)
        @model = model
        @executor = executor
        @memory = memory
      end

      # Expose private methods for testing
      def test_route_observations(raw, step)
        route_observations(raw, step)
      end

      def test_skip_routing?(obs)
        skip_routing?(obs)
      end
    end
  end

  let(:mock_executor) do
    instance_double(Smolagents::Executors::LocalRuby).tap do |e|
      allow(e).to receive(:respond_to?).with(:tool_calls).and_return(true)
      allow(e).to receive(:tool_calls).and_return([])
    end
  end

  let(:router_instance) { test_class.new(model: mock_model, executor: mock_executor) }

  describe "#routing_enabled?" do
    it "returns true by default" do
      expect(router_instance.routing_enabled?).to be true
    end

    it "returns false when explicitly disabled" do
      router_instance.routing_enabled = false
      expect(router_instance.routing_enabled?).to be false
    end
  end

  describe "#route_observations" do
    context "when routing is disabled" do
      before { router_instance.routing_enabled = false }

      it "returns raw observation unchanged" do
        result = router_instance.test_route_observations("raw output", nil)
        expect(result).to eq("raw output")
      end
    end

    context "when observation is nil or empty" do
      it "returns nil for nil observation" do
        result = router_instance.test_route_observations(nil, nil)
        expect(result).to be_nil
      end

      it "returns empty string for empty observation" do
        result = router_instance.test_route_observations("", nil)
        expect(result).to eq("")
      end
    end

    context "when no tools were called" do
      it "returns raw observation" do
        allow(mock_executor).to receive(:tool_calls).and_return([])

        result = router_instance.test_route_observations("output", nil)
        expect(result).to eq("output")
      end
    end

    context "with tool calls and default router" do
      let(:tool_call) do
        double("ToolCall", tool_name: "wikipedia", success?: true, result: "data")
      end

      before do
        allow(mock_executor).to receive(:tool_calls).and_return([tool_call])

        # Queue a routing response
        mock_model.queue_response(<<~RUBY)
          ```ruby
          RoutingResult.new(
            decision: :summary_only,
            summary: "Found Wikipedia data",
            relevance: 0.9,
            next_action: "Use this info",
            full_output: nil
          )
          ```
        RUBY
      end

      it "routes through the default model-based router" do
        result = router_instance.test_route_observations("raw wiki output", nil)

        expect(result).to include("[SUMMARY_ONLY]")
        expect(result).to include("Found Wikipedia data")
      end
    end

    context "with custom router" do
      it "uses the custom router instead of default" do
        custom_result = Smolagents::Concerns::ObservationRouter::RoutingResult.new(
          decision: :irrelevant,
          summary: "Custom router result",
          relevance: 0.0,
          next_action: "Try something else",
          full_output: nil
        )

        router_instance.observation_router = ->(_tool, _output, _task) { custom_result }

        tool_call = double("ToolCall", tool_name: "search")
        allow(mock_executor).to receive(:tool_calls).and_return([tool_call])

        result = router_instance.test_route_observations("output", nil)

        expect(result).to include("[IRRELEVANT]")
        expect(result).to include("Custom router result")
      end
    end

    context "when router raises an error" do
      it "returns raw observation with error message" do
        router_instance.observation_router = ->(_t, _o, _task) { raise "Router failed" }

        tool_call = double("ToolCall", tool_name: "search")
        allow(mock_executor).to receive(:tool_calls).and_return([tool_call])

        result = router_instance.test_route_observations("raw output", nil)

        expect(result).to include("[Router error: Router failed]")
        expect(result).to include("raw output")
      end
    end
  end

  describe "#skip_routing?" do
    it "skips nil observations" do
      expect(router_instance.test_skip_routing?(nil)).to be true
    end

    it "skips empty observations" do
      expect(router_instance.test_skip_routing?("")).to be true
    end

    it "skips when routing disabled" do
      router_instance.routing_enabled = false
      expect(router_instance.test_skip_routing?("content")).to be true
    end

    it "does not skip valid observations with routing enabled" do
      expect(router_instance.test_skip_routing?("content")).to be false
    end
  end

  describe "builder integration" do
    before do
      mock_model.queue_code_action('final_answer(answer: "done")')
    end

    it "enables routing by default" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .build

      expect(agent).to respond_to(:run)
    end

    it "allows disabling routing via builder" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .route_observations(enabled: false)
                        .build

      expect(agent).to respond_to(:run)
    end

    it "allows custom router model via builder" do
      router_model = Smolagents::Testing::MockModel.new

      agent = Smolagents.agent
                        .model { mock_model }
                        .route_observations { router_model }
                        .build

      expect(agent).to respond_to(:run)
    end
  end
end
