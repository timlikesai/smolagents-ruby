require "spec_helper"
require_relative "../../../experiments/multi_model_agents/09_distributed_analyst"

RSpec.describe "Experiment: Distributed Analyst", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "QueryClassification" do
    it "creates immutable classification data" do
      classification = Experiments::DistributedAnalyst::QueryClassification.new(
        category: :research,
        confidence: 0.9,
        reasoning: "Contains research keywords"
      )

      expect(classification.category).to eq(:research)
      expect(classification.confidence).to eq(0.9)
    end

    it "provides category predicates" do
      simple = Experiments::DistributedAnalyst::QueryClassification.new(
        category: :simple, confidence: 0.8, reasoning: ""
      )
      research = Experiments::DistributedAnalyst::QueryClassification.new(
        category: :research, confidence: 0.8, reasoning: ""
      )
      analysis = Experiments::DistributedAnalyst::QueryClassification.new(
        category: :analysis, confidence: 0.8, reasoning: ""
      )
      visual = Experiments::DistributedAnalyst::QueryClassification.new(
        category: :visual, confidence: 0.8, reasoning: ""
      )

      expect(simple.simple?).to be true
      expect(research.research?).to be true
      expect(analysis.analysis?).to be true
      expect(visual.visual?).to be true
    end
  end

  describe "AnalystMetrics" do
    let(:metrics) { Experiments::DistributedAnalyst::AnalystMetrics.new }

    it "tracks query classifications" do
      metrics.track_classification(:simple)
      metrics.track_classification(:simple)
      metrics.track_classification(:research)

      expect(metrics.classifications[:simple]).to eq(2)
      expect(metrics.classifications[:research]).to eq(1)
    end

    it "tracks model usage with latency" do
      metrics.track_model("gpt-4", 100)
      metrics.track_model("gpt-4", 150)
      metrics.track_model("gpt-3.5", 50)

      expect(metrics.model_usage["gpt-4"]).to eq(2)
      expect(metrics.model_usage["gpt-3.5"]).to eq(1)
    end

    it "tracks errors" do
      metrics.track_error("NetworkError", "Connection refused")

      expect(metrics.errors.size).to eq(1)
      expect(metrics.errors.first[:error_class]).to eq("NetworkError")
    end

    it "provides comprehensive summary" do
      metrics.track_classification(:simple)
      metrics.track_classification(:research)
      metrics.track_model("gpt-4", 100)
      metrics.track_error("TestError", "test")

      summary = metrics.summary

      expect(summary[:total_queries]).to eq(2)
      expect(summary[:classifications]).to eq({ simple: 1, research: 1 })
      expect(summary[:model_usage]).to eq({ "gpt-4" => 1 })
      expect(summary[:error_count]).to eq(1)
    end

    it "is thread-safe" do
      threads = Array.new(10) do |i|
        Thread.new do
          metrics.track_classification(:simple)
          metrics.track_model("model-#{i}", 10)
        end
      end
      threads.each(&:join)

      expect(metrics.classifications[:simple]).to eq(10)
      expect(metrics.model_usage.values.sum).to eq(10)
    end
  end

  describe "Models module" do
    describe ".fast_triage" do
      it "creates builder with health check and fallback" do
        builder = Experiments::DistributedAnalyst::Models.fast_triage

        expect(builder).to be_a(Smolagents::Builders::ModelBuilder)
        expect(builder.config[:health_check]).not_to be_nil
        expect(builder.config[:prefer_healthy]).to be true
      end
    end

    describe ".research_worker" do
      it "creates builder for parallel workers" do
        builder = Experiments::DistributedAnalyst::Models.research_worker

        expect(builder).to be_a(Smolagents::Builders::ModelBuilder)
        expect(builder.config[:timeout]).to eq(30)
      end
    end

    describe ".reasoning" do
      it "creates builder for complex reasoning" do
        builder = Experiments::DistributedAnalyst::Models.reasoning

        expect(builder.config[:model_id]).to eq("gpt-oss-120b")
        expect(builder.config[:timeout]).to eq(120)
        expect(builder.config[:circuit_breaker]).not_to be_nil
      end
    end
  end

  describe ".build_classifier" do
    it "creates classifier agent with classify tool" do
      model = mock_model { |m| m.queue_final_answer("classified") }
      metrics = Experiments::DistributedAnalyst::AnalystMetrics.new

      agent = Experiments::DistributedAnalyst.build_classifier(
        model:,
        metrics:
      )

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("classify")
    end
  end

  describe ".build_synthesizer" do
    it "creates synthesizer agent" do
      model = mock_model { |m| m.queue_final_answer("synthesized") }

      agent = Experiments::DistributedAnalyst.build_synthesizer(model:)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("format_response")
    end
  end

  describe ".build_analyst" do
    it "creates complete analyst system" do
      triage = mock_model { |m| m.queue_final_answer("done") }
      research = mock_model { |m| m.queue_final_answer("found") }
      reasoning = mock_model { |m| m.queue_final_answer("analyzed") }

      result = Experiments::DistributedAnalyst.build_analyst(
        triage_model: triage,
        research_model: research,
        reasoning_model: reasoning
      )

      expect(result[:coordinator]).to be_a(Smolagents::Agents::Agent)
      expect(result[:metrics]).to be_a(Experiments::DistributedAnalyst::AnalystMetrics)
      expect(result[:subsystems].keys).to contain_exactly(
        :classifier, :research, :visual, :synthesizer
      )
    end

    it "wires up all subsystems as team agents" do
      triage = mock_model { |m| m.queue_final_answer("done") }
      research = mock_model { |m| m.queue_final_answer("found") }
      reasoning = mock_model { |m| m.queue_final_answer("analyzed") }

      result = Experiments::DistributedAnalyst.build_analyst(
        triage_model: triage,
        research_model: research,
        reasoning_model: reasoning
      )

      coordinator_tools = result[:coordinator].tools.keys
      expect(coordinator_tools).to include("classifier")
      expect(coordinator_tools).to include("research_team")
      expect(coordinator_tools).to include("visual_analyzer")
      expect(coordinator_tools).to include("synthesizer")
    end
  end

  describe ".build_for_testing" do
    it "creates test setup with all mock models" do
      result = Experiments::DistributedAnalyst.build_for_testing(
        triage_responses: ["<code>\nfinal_answer(answer: \"classified\")\n</code>"],
        reasoning_responses: ["<code>\nfinal_answer(answer: \"analyzed\")\n</code>"]
      )

      expect(result[:coordinator]).to be_a(Smolagents::Agents::Agent)
      expect(result[:models]).to include(:triage, :research, :reasoning)
      expect(result[:metrics]).to be_a(Experiments::DistributedAnalyst::AnalystMetrics)
    end
  end

  describe "coordinator execution" do
    it "can complete simple queries directly" do
      result = Experiments::DistributedAnalyst.build_for_testing(
        triage_responses: ["<code>\nfinal_answer(answer: \"Direct answer\")\n</code>"],
        reasoning_responses: []
      )

      run_result = result[:coordinator].run("What is 2+2?")

      expect(run_result.output).to eq("Direct answer")
    end
  end
end
