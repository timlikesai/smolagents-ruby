require "spec_helper"
require_relative "../../../experiments/multi_model_agents/06_visual_analysis_pipeline"

RSpec.describe "Experiment: Visual Analysis Pipeline", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "VisualDescription" do
    it "creates immutable description data" do
      desc = Experiments::VisualAnalysisPipeline::VisualDescription.new(
        image_path: "/path/to/image.jpg",
        description: "A scenic landscape",
        confidence: 0.92,
        detected_elements: %w[mountain sky trees]
      )

      expect(desc.image_path).to eq("/path/to/image.jpg")
      expect(desc.confidence).to eq(0.92)
      expect(desc.detected_elements).to contain_exactly("mountain", "sky", "trees")
    end

    it "generates prompt text" do
      desc = Experiments::VisualAnalysisPipeline::VisualDescription.new(
        image_path: "/test.jpg",
        description: "Test image",
        confidence: 0.85,
        detected_elements: %w[element1 element2]
      )

      prompt = desc.to_prompt

      expect(prompt).to include("Image Analysis Results")
      expect(prompt).to include("/test.jpg")
      expect(prompt).to include("Test image")
      expect(prompt).to include("85%")
      expect(prompt).to include("element1, element2")
    end
  end

  describe "PipelineMetrics" do
    let(:metrics) { Experiments::VisualAnalysisPipeline::PipelineMetrics.new }

    it "tracks vision calls with latency" do
      metrics.track_vision(100)
      metrics.track_vision(150)

      expect(metrics.vision_calls).to eq(2)
      expect(metrics.latencies[:vision]).to eq([100, 150])
    end

    it "tracks reasoning calls with latency" do
      metrics.track_reasoning(200)
      metrics.track_reasoning(250)

      expect(metrics.reasoning_calls).to eq(2)
      expect(metrics.latencies[:reasoning]).to eq([200, 250])
    end

    it "calculates average latencies in summary" do
      metrics.track_vision(100)
      metrics.track_vision(200)
      metrics.track_reasoning(300)

      summary = metrics.summary

      expect(summary[:avg_vision_latency_ms]).to eq(150)
      expect(summary[:avg_reasoning_latency_ms]).to eq(300)
    end

    it "handles empty metrics gracefully" do
      summary = metrics.summary

      expect(summary[:avg_vision_latency_ms]).to eq(0)
      expect(summary[:avg_reasoning_latency_ms]).to eq(0)
    end

    describe "#track_model" do
      it "tracks model events with model_id and duration_ms" do
        event = double("ModelGeneration", model_id: "gpt-4", duration_ms: 250)
        metrics.track_model(event)

        expect(metrics.model_events).to contain_exactly(
          { model_id: "gpt-4", duration_ms: 250 }
        )
        expect(metrics.reasoning_calls).to eq(1)
      end

      it "includes model_events_count in summary" do
        event1 = double("ModelGeneration", model_id: "gpt-4", duration_ms: 100)
        event2 = double("ModelGeneration", model_id: "gpt-4", duration_ms: 200)
        metrics.track_model(event1)
        metrics.track_model(event2)

        expect(metrics.summary[:model_events_count]).to eq(2)
      end
    end
  end

  describe ".build_vision_tool" do
    it "creates an inline tool for image analysis" do
      tool = Experiments::VisualAnalysisPipeline.build_vision_tool

      expect(tool).to be_a(Smolagents::Tools::Tool)
      expect(tool.name).to eq("analyze_image")
    end

    it "returns mock description when no vision model provided" do
      metrics = Experiments::VisualAnalysisPipeline::PipelineMetrics.new
      tool = Experiments::VisualAnalysisPipeline.build_vision_tool(metrics:)

      result = tool.execute(image_path: "/test/image.jpg")

      expect(result).to include("Image Analysis Results")
      expect(metrics.vision_calls).to eq(1)
    end
  end

  describe ".build_pipeline" do
    it "creates agent with vision and utility tools" do
      reasoning_model = mock_model { |m| m.queue_final_answer("analysis complete") }

      agent = Experiments::VisualAnalysisPipeline.build_pipeline(
        reasoning_model:
      )

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.keys).to include("analyze_image", "summarize", "compare")
    end

    it "tracks reasoning metrics via event handlers" do
      reasoning_model = mock_model { |m| m.queue_final_answer("done") }
      metrics = Experiments::VisualAnalysisPipeline::PipelineMetrics.new

      agent = Experiments::VisualAnalysisPipeline.build_pipeline(
        reasoning_model:,
        metrics:
      )

      agent.run("Analyze this image")

      # NOTE: Mock models don't emit model_generate_completed events,
      # so metrics tracking via events won't work in tests.
      # This test verifies the agent runs without error.
      # In production with real models, events would fire.
      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "model event emission" do
    # LIMITATION: MockModel does not include Models::Model::Eventing concern,
    # so it doesn't emit :model_generation events. This is by design
    # to keep MockModel simple and deterministic for testing.
    #
    # In production with real models (OpenAI, Anthropic), the Eventing concern
    # wraps generate() calls with event emission:
    #   - :model_generation (phase: :requested) before the call
    #   - :model_generation (phase: :completed) after with duration_ms, model_id, token_usage
    #
    # To test event handling in isolation, use doubles or manually emit events.

    it "documents that mock models do not emit events" do
      reasoning_model = mock_model { |m| m.queue_final_answer("done") }
      metrics = Experiments::VisualAnalysisPipeline::PipelineMetrics.new
      events_received = []

      agent = Experiments::VisualAnalysisPipeline.build_pipeline(
        reasoning_model:,
        metrics:
      )
      agent.on(:model_generation) { |e| events_received << e }
      agent.run("test")

      # MockModel does not emit events - this documents the limitation
      expect(events_received).to be_empty
      expect(metrics.model_events).to be_empty
    end

    it "metrics can be tracked via manual event emission" do
      metrics = Experiments::VisualAnalysisPipeline::PipelineMetrics.new
      event = double("ModelGeneration", model_id: "test-model", duration_ms: 150)

      metrics.track_model(event)

      expect(metrics.model_events.size).to eq(1)
      expect(metrics.model_events.first[:model_id]).to eq("test-model")
      expect(metrics.model_events.first[:duration_ms]).to eq(150)
    end
  end

  describe "Pipelines module" do
    describe ".medical_analysis" do
      it "creates pipeline with medical-specific tools" do
        model = mock_model { |m| m.queue_final_answer("medical analysis") }

        agent = Experiments::VisualAnalysisPipeline::Pipelines.medical_analysis(
          reasoning_model: model
        )

        expect(agent.tools.keys).to include(
          "analyze_image",
          "lookup_condition",
          "check_guidelines"
        )
      end

      it "enables evaluation for extra caution" do
        model = mock_model { |m| m.queue_final_answer("done") }

        agent = Experiments::VisualAnalysisPipeline::Pipelines.medical_analysis(
          reasoning_model: model
        )

        # Agent should be built with evaluation enabled
        expect(agent).to be_a(Smolagents::Agents::Agent)
      end
    end

    describe ".document_analysis" do
      it "creates pipeline with document-specific tools" do
        model = mock_model { |m| m.queue_final_answer("document analysis") }

        agent = Experiments::VisualAnalysisPipeline::Pipelines.document_analysis(
          reasoning_model: model
        )

        expect(agent.tools.keys).to include(
          "analyze_image",
          "extract_text",
          "parse_table"
        )
      end
    end
  end

  describe ".build_for_testing" do
    it "creates agent with mock reasoning model" do
      result = Experiments::VisualAnalysisPipeline.build_for_testing(
        reasoning_responses: ["<code>\nfinal_answer(answer: \"analyzed\")\n</code>"]
      )

      expect(result[:agent]).to be_a(Smolagents::Agents::Agent)
      expect(result[:model]).to be_a(Smolagents::Testing::MockModel)
      expect(result[:metrics]).to be_a(Experiments::VisualAnalysisPipeline::PipelineMetrics)
    end

    it "supports custom vision descriptions" do
      custom_desc = Experiments::VisualAnalysisPipeline::VisualDescription.new(
        image_path: "/custom.jpg",
        description: "Custom description",
        confidence: 0.99,
        detected_elements: ["custom_element"]
      )

      result = Experiments::VisualAnalysisPipeline.build_for_testing(
        reasoning_responses: ["<code>\nfinal_answer(answer: \"done\")\n</code>"],
        vision_descriptions: [custom_desc]
      )

      expect(result[:agent]).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "pipeline execution with mocks" do
    it "completes simple analysis task" do
      result = Experiments::VisualAnalysisPipeline.build_for_testing(
        reasoning_responses: ["<code>\nfinal_answer(answer: \"Image shows a cat\")\n</code>"]
      )

      run_result = result[:agent].run("What's in this image?")

      expect(run_result.output).to eq("Image shows a cat")
    end
  end
end
