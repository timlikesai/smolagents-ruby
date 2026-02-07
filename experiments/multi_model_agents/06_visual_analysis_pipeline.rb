# Experiment: Visual Analysis Pipeline
#
# Image input → Vision model analysis → Reasoning model interpretation.
# Demonstrates multimodal agent composition and specialized model routing.
#
# Architecture:
#   Image → [Vision Model (MedGemma)] → Description → [Reasoning Model (120B)] → Analysis
#
# Use cases:
#   - Medical image analysis
#   - Document understanding
#   - Visual QA
#   - Chart/graph interpretation
#
# Run: ruby experiments/multi_model_agents/06_visual_analysis_pipeline.rb
# Test: bundle exec rspec spec/experiments/multi_model_agents/06_visual_analysis_pipeline_spec.rb

require_relative "../../lib/smolagents"

module Experiments
  module VisualAnalysisPipeline
    # Infrastructure endpoints
    MACBOOK_PRO = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1".freeze

    # Vision analysis result
    VisualDescription = Data.define(:image_path, :description, :confidence, :detected_elements) do
      def to_prompt
        <<~PROMPT
          Image Analysis Results:
          - Source: #{image_path}
          - Description: #{description}
          - Detected Elements: #{detected_elements.join(", ")}
          - Confidence: #{(confidence * 100).round}%
        PROMPT
      end
    end

    # Pipeline metrics with event-based model tracking
    class PipelineMetrics
      attr_reader :vision_calls, :reasoning_calls, :latencies, :model_events

      def initialize
        @vision_calls = 0
        @reasoning_calls = 0
        @latencies = { vision: [], reasoning: [] }
        @model_events = []
      end

      def track_vision(duration_ms)
        @vision_calls += 1
        @latencies[:vision] << duration_ms
      end

      def track_reasoning(duration_ms)
        @reasoning_calls += 1
        @latencies[:reasoning] << duration_ms
      end

      # Track model events from :model_generation
      def track_model(event)
        @model_events << { model_id: event.model_id, duration_ms: event.duration_ms }
        track_reasoning(event.duration_ms)
      end

      def summary
        {
          vision_calls: @vision_calls,
          reasoning_calls: @reasoning_calls,
          avg_vision_latency_ms: avg_latency(:vision),
          avg_reasoning_latency_ms: avg_latency(:reasoning),
          model_events_count: @model_events.size
        }
      end

      private

      def avg_latency(type)
        data = @latencies[type]
        data.empty? ? 0 : data.sum / data.size
      end
    end

    # Build a visual analysis tool that wraps the vision model
    #
    # In production, this would call a vision model like MedGemma.
    # For testing, we inject a mock vision handler.
    def self.build_vision_tool(vision_model: nil, metrics: nil)
      # Capture in closure for the block
      vm = vision_model
      m = metrics

      Smolagents::InlineTool.create(
        :analyze_image,
        "Analyze an image and extract detailed description",
        image_path: String
      ) do |image_path:|
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # In production: call vision model with image
        # For now: simulate with mock or real model
        description = if vm
                        # Real vision model call
                        vm.generate([
                                      {
                                        role: "user",
                                        content: [
                                          { type: "image_url", image_url: { url: image_path } },
                                          { type: "text", text: "Describe this image in detail" }
                                        ]
                                      }
                                    ])
                      else
                        # Mock response for testing
                        VisualDescription.new(
                          image_path:,
                          description: "A detailed view showing relevant elements",
                          confidence: 0.85,
                          detected_elements: %w[element1 element2 element3]
                        )
                      end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        m&.track_vision(duration_ms)

        description.respond_to?(:to_prompt) ? description.to_prompt : description.to_s
      end
    end

    # Build the visual analysis pipeline agent
    #
    # @param reasoning_model [Model] Model for interpretation and reasoning
    # @param vision_model [Model, nil] Optional vision model (uses mock if nil)
    # @param metrics [PipelineMetrics, nil] Optional metrics collector
    # @return [Agent] Configured pipeline agent
    def self.build_pipeline(reasoning_model:, vision_model: nil, metrics: nil)
      collector = metrics || PipelineMetrics.new
      vision_tool = build_vision_tool(vision_model:, metrics: collector)

      Smolagents.agent
                .model(:execution) { reasoning_model }
                .tools(vision_tool)
                .tool(:summarize, "Summarize findings", text: String) { |text:| "Summary: #{text[0..200]}..." }
                .tool(:compare, "Compare two items", item_a: String, item_b: String) do |item_a:, item_b:|
                  "Comparison of #{item_a} vs #{item_b}: [similarities and differences]"
      end
               .instructions(<<~INST)
                 You are a visual analysis assistant.

                 When given an image to analyze:
                 1. Use analyze_image to extract visual information
                 2. Interpret the results in context of the user's question
                 3. Provide actionable insights based on the visual data

                 Be specific and reference detected elements in your analysis.
               INST
               .max_steps(10)
               .on(:model_generation) { |e| collector.track_model(e) if e.completed? }
               .build
    end

    # Build specialized pipelines for different use cases
    module Pipelines
      # Medical image analysis (would use MedGemma in production)
      def self.medical_analysis(reasoning_model:, vision_model: nil)
        metrics = PipelineMetrics.new

        Smolagents.agent
                  .model(:execution) { reasoning_model }
                  .tools(VisualAnalysisPipeline.build_vision_tool(vision_model:, metrics:))
                  .tool(:lookup_condition, "Look up medical condition", condition: String) do |condition:|
                    "Medical reference for #{condition}: [symptoms, treatments, prognosis]"
        end
                 .tool(:check_guidelines, "Check clinical guidelines", topic: String) do |topic:|
                   "Clinical guidelines for #{topic}: [recommendations]"
                 end
                 .instructions(<<~INST)
                   You are a medical image analysis assistant.

                   IMPORTANT: You provide analysis to support medical professionals, not replace them.
                   Always recommend consultation with qualified healthcare providers.

                   When analyzing medical images:
                   1. Extract visual information using analyze_image
                   2. Identify potential areas of interest
                   3. Reference relevant clinical guidelines
                   4. Note limitations and uncertainties
                 INST
                 .max_steps(8)
                 .evaluation(enabled: true) # Extra caution for medical
                 .on(:model_generation) { |e| metrics.track_model(e) if e.completed? }
                 .build
      end

      # Document/chart analysis
      def self.document_analysis(reasoning_model:, vision_model: nil)
        metrics = PipelineMetrics.new

        Smolagents.agent
                  .model(:execution) { reasoning_model }
                  .tools(VisualAnalysisPipeline.build_vision_tool(vision_model:, metrics:))
                  .tool(:extract_text, "OCR text extraction", image_path: String) do |image_path:|
                    "Extracted text from #{image_path}: [document content]"
        end
                 .tool(:parse_table, "Parse table structure", image_path: String) do |image_path:|
                   "Table from #{image_path}: | Col1 | Col2 | Col3 |"
                 end
                 .instructions(<<~INST)
                   You are a document analysis assistant.

                   When analyzing documents, charts, or diagrams:
                   1. First get visual overview with analyze_image
                   2. Extract specific text or data as needed
                   3. Parse structured elements (tables, charts)
                   4. Synthesize findings into clear summary
                 INST
                 .max_steps(10)
                 .on(:model_generation) { |e| metrics.track_model(e) if e.completed? }
                 .build
      end
    end

    # Build for testing with mock models
    def self.build_for_testing(reasoning_responses:, vision_descriptions: [])
      reasoning_model = Smolagents::Testing::MockModel.new(model_id: "mock-reasoning")
      reasoning_responses.each { |r| reasoning_model.queue_response(r) }

      metrics = PipelineMetrics.new

      # Create a mock vision tool that returns canned descriptions
      description_queue = vision_descriptions.dup
      m = metrics # Capture for closure
      mock_vision_tool = Smolagents::InlineTool.create(
        :analyze_image,
        "Analyze image (mock)",
        image_path: String
      ) do |image_path:|
        desc = description_queue.shift || VisualDescription.new(
          image_path:,
          description: "Mock description",
          confidence: 0.9,
          detected_elements: ["mock_element"]
        )
        m.track_vision(50) # Simulate 50ms latency
        desc.respond_to?(:to_prompt) ? desc.to_prompt : desc.to_s
      end

      agent = Smolagents.agent
                        .model(:execution) { reasoning_model }
                        .tools(mock_vision_tool)
                        .max_steps(5)
                        .on(:model_generation) { |e| metrics.track_model(e) if e.completed? }
                        .build

      { agent:, model: reasoning_model, metrics: }
    end
  end
end

# =============================================================================
# DEMO
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Visual Analysis Pipeline Experiment"
  puts "=" * 40
  puts
  puts "This experiment demonstrates:"
  puts "1. Multimodal agent composition (vision + reasoning)"
  puts "2. Specialized pipelines for different domains"
  puts "3. Tool-wrapped model calls for vision processing"
  puts "4. Metrics tracking across the pipeline"
  puts
  puts "Pipelines available:"
  puts "  - General visual analysis"
  puts "  - Medical image analysis (with safety guardrails)"
  puts "  - Document/chart analysis"
  puts
  puts "To test:"
  puts "  bundle exec rspec spec/experiments/multi_model_agents/06_visual_analysis_pipeline_spec.rb"
end
