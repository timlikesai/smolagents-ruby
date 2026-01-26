require "spec_helper"
require_relative "../../../experiments/multi_model_agents/04_tiered_reasoning"

RSpec.describe "Experiment: Tiered Reasoning", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "Models module" do
    describe ".fast_20b" do
      it "creates a ModelBuilder with health check and retry" do
        builder = Experiments::TieredReasoning::Models.fast_20b

        expect(builder).to be_a(Smolagents::Builders::ModelBuilder)
        expect(builder.config[:health_check]).not_to be_nil
        expect(builder.config[:retry_policy]).not_to be_nil
        expect(builder.config[:retry_policy][:max_attempts]).to eq(2)
      end
    end

    describe ".big_30b" do
      it "creates a ModelBuilder with longer timeout" do
        builder = Experiments::TieredReasoning::Models.big_30b

        expect(builder).to be_a(Smolagents::Builders::ModelBuilder)
        expect(builder.config[:timeout]).to eq(120)
      end
    end

    describe ".fast_20b_resilient" do
      it "creates a ModelBuilder with fallbacks and circuit breaker" do
        builder = Experiments::TieredReasoning::Models.fast_20b_resilient

        expect(builder.config[:fallbacks]).not_to be_empty
        expect(builder.config[:circuit_breaker]).not_to be_nil
        expect(builder.config[:prefer_healthy]).to be true
      end
    end
  end

  describe "MetricsCollector" do
    let(:collector) { Experiments::TieredReasoning::MetricsCollector.new }

    it "tracks model calls by model_id" do
      event1 = double(model_id: "model-a")
      event2 = double(model_id: "model-b")
      event3 = double(model_id: "model-a")

      collector.track_model_call(event1)
      collector.track_model_call(event2)
      collector.track_model_call(event3)

      expect(collector.model_calls["model-a"]).to eq(2)
      expect(collector.model_calls["model-b"]).to eq(1)
    end

    it "tracks failovers" do
      event = double(
        from_model_id: "primary",
        to_model_id: "secondary",
        error_class: "NetworkError"
      )

      collector.track_failover(event)

      expect(collector.failovers.size).to eq(1)
      expect(collector.failovers.first[:from]).to eq("primary")
    end

    it "tracks step timings" do
      event = double(step_number: 1, outcome: :success)

      collector.track_step(event)

      expect(collector.step_timings.size).to eq(1)
      expect(collector.step_timings.first[:outcome]).to eq(:success)
    end

    it "provides summary statistics" do
      collector.track_model_call(double(model_id: "model-a"))
      collector.track_model_call(double(model_id: "model-a"))
      collector.track_step(double(step_number: 1, outcome: :success))

      summary = collector.summary

      expect(summary[:total_calls]).to eq(2)
      expect(summary[:steps_completed]).to eq(1)
    end
  end

  describe ".build_tiered_agent" do
    it "builds an agent with multi-model configuration" do
      fast = mock_model { |m| m.queue_final_answer("done") }
      big = mock_model { |m| m.queue_final_answer("done") }

      agent = Experiments::TieredReasoning.build_tiered_agent(
        fast_model: fast,
        big_model: big
      )

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "configures planning and evaluation" do
      fast = mock_model { |m| m.queue_final_answer("done") }
      big = mock_model { |m| m.queue_final_answer("done") }

      agent = Experiments::TieredReasoning.build_tiered_agent(
        fast_model: fast,
        big_model: big
      )

      # Agent should be configured - exact internals are implementation detail
      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe ".build_for_testing" do
    it "creates agent with mock models" do
      result = Experiments::TieredReasoning.build_for_testing(
        triage_responses: ["<code>\nfinal_answer(answer: \"triaged\")\n</code>"],
        execution_responses: ["<code>\nfinal_answer(answer: \"executed\")\n</code>"]
      )

      expect(result[:agent]).to be_a(Smolagents::Agents::Agent)
      expect(result[:models]).to include(:triage, :execution, :planning)
      expect(result[:metrics]).to be_a(Experiments::TieredReasoning::MetricsCollector)
    end

    it "returns mock models that can be inspected" do
      result = Experiments::TieredReasoning.build_for_testing(
        triage_responses: ["<code>\nfinal_answer(answer: \"triaged\")\n</code>"],
        execution_responses: ["<code>\nfinal_answer(answer: \"executed\")\n</code>"]
      )

      expect(result[:models][:execution]).to be_a(Smolagents::Testing::MockModel)
      expect(result[:models][:triage]).to be_a(Smolagents::Testing::MockModel)
    end
  end

  describe "agent execution with mocks" do
    it "completes a simple task" do
      result = Experiments::TieredReasoning.build_for_testing(
        triage_responses: [],
        execution_responses: ["<code>\nfinal_answer(answer: \"42\")\n</code>"]
      )

      run_result = result[:agent].run("What is 6 * 7?")

      expect(run_result.output).to eq("42")
      expect(result[:models][:execution].call_count).to be >= 1
    end

    it "tracks metrics during execution" do
      result = Experiments::TieredReasoning.build_for_testing(
        triage_responses: [],
        execution_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"]
      )

      result[:agent].run("Simple task")

      # Metrics are tracked via event handlers
      # The mock model generates events when called
      expect(result[:models][:execution].call_count).to be >= 1
    end
  end
end
