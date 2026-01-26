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

      def test_skip_formatting?(obs)
        skip_observation_formatting?(obs)
      end
    end
  end

  let(:mock_executor) do
    instance_double(Smolagents::Executors::Ractor).tap do |e|
      allow(e).to receive(:respond_to?).with(:tool_calls).and_return(true)
      allow(e).to receive(:tool_calls).and_return([])
    end
  end

  let(:router_instance) { test_class.new(model: mock_model, executor: mock_executor) }

  describe "#skip_observation_formatting?" do
    it "skips nil observations" do
      expect(router_instance.test_skip_formatting?(nil)).to be true
    end

    it "skips empty observations" do
      expect(router_instance.test_skip_formatting?("")).to be true
    end

    it "does not skip valid observations" do
      expect(router_instance.test_skip_formatting?("content")).to be false
    end
  end

  describe "#route_observations" do
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

    context "when formatting fails" do
      let(:action_step) { double("ActionStep") }

      it "returns raw observation with error message" do
        allow(action_step).to receive(:action_output).and_raise("Something broke")

        result = router_instance.test_route_observations("raw output", action_step)

        expect(result).to include("[Observation formatting error: Something broke]")
        expect(result).to include("raw output")
      end
    end
  end

  describe "observe modes" do
    let(:action_step) do
      double("ActionStep", action_output: [{ "title" => "Ruby 4.0", "link" => "https://example.com" }])
    end

    let(:tool_call) do
      double("ToolCall", tool_name: "search", success?: true, result: "data")
    end

    before do
      allow(mock_executor).to receive(:tool_calls).and_return([tool_call])
    end

    context "with :structure_only mode" do
      before { router_instance.observe_mode = :structure_only }

      it "includes data structure info" do
        result = router_instance.test_route_observations("raw output", action_step)

        expect(result).to include("## Result")
        expect(result).to include("result = Array[1]")
        expect(result).to include('Each element has keys: "title", "link"')
      end

      it "includes truncated raw output" do
        result = router_instance.test_route_observations("raw output", action_step)

        expect(result).to include("## Output")
        expect(result).to include("raw output")
      end

      it "does not call the model" do
        router_instance.test_route_observations("raw output", action_step)
        expect(mock_model.calls).to be_empty
      end
    end

    context "with :with_summary mode (default)" do
      before do
        router_instance.observe_mode = :with_summary
        mock_model.queue_response(<<~RESPONSE)
          SUMMARY: Found search results
          RELEVANCE: High - matches query
          NEXT: Extract first result
        RESPONSE
      end

      it "includes data structure info" do
        result = router_instance.test_route_observations("raw output", action_step)

        expect(result).to include("## Result")
        expect(result).to include("result = Array[1]")
      end

      it "includes LLM summary" do
        result = router_instance.test_route_observations("raw output", action_step)

        expect(result).to include("Summary:")
        expect(result).to include("Found search results")
      end

      it "calls the model for summary" do
        router_instance.test_route_observations("raw output", action_step)
        expect(mock_model.calls.size).to eq(1)
      end
    end

    context "with custom summarizer model" do
      let(:summarizer_model) { Smolagents::Testing::MockModel.new }

      before do
        router_instance.observe_mode = :with_summary
        router_instance.summarizer_model = summarizer_model
        summarizer_model.queue_response("SUMMARY: Custom model summary")
      end

      it "uses the custom model instead of agent model" do
        router_instance.test_route_observations("raw output", action_step)

        expect(summarizer_model.calls.size).to eq(1)
        expect(mock_model.calls).to be_empty
      end
    end

    context "with nil observe_mode (defaults to :with_summary)" do
      before do
        router_instance.observe_mode = nil
        mock_model.queue_response("SUMMARY: Default mode summary")
      end

      it "formats with summary" do
        result = router_instance.test_route_observations("raw output", action_step)

        expect(result).to include("## Result")
        expect(result).to include("Summary:")
      end
    end
  end

  describe "builder integration" do
    before do
      mock_model.queue_code_action('final_answer(answer: "done")')
    end

    it "enables :with_summary mode by default" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .build

      expect(agent).to respond_to(:run)
    end

    it "allows :structure_only mode" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .observe(:structure_only)
                        .build

      expect(agent).to respond_to(:run)
    end

    it "allows :with_summary with custom model" do
      summarizer = Smolagents::Testing::MockModel.new

      agent = Smolagents.agent
                        .model { mock_model }
                        .observe(:with_summary) { summarizer }
                        .build

      expect(agent).to respond_to(:run)
    end

    it "raises on invalid observe mode" do
      expect do
        Smolagents.agent
                  .model { mock_model }
                  .observe(:invalid_mode)
      end.to raise_error(ArgumentError, /Invalid observe mode/)
    end
  end
end
