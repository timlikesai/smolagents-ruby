# Experiment: Distributed Analyst
#
# A comprehensive agent that demonstrates the full power of the distributed
# multi-model infrastructure. Combines tiered reasoning, parallel research,
# and visual analysis into a single cohesive system.
#
# Infrastructure Used:
#   - LLaMA Ultra (fast 20B): Quick triage, simple queries
#   - MacBook Pro (fast 20B): Parallel research workers
#   - MacBook Pro (120B): Complex reasoning, synthesis
#   - Mac Studio (20B): Fallback capacity
#
# Architecture:
#   ┌─────────────────────────────────────────────────────────────┐
#   │                    User Query                                │
#   └──────────────────────┬──────────────────────────────────────┘
#                          │
#   ┌──────────────────────▼──────────────────────────────────────┐
#   │              Triage (Fast 20B)                              │
#   │    Classify: simple | research | analysis | visual         │
#   └──────────┬───────────┬───────────┬────────────┬────────────┘
#              │           │           │            │
#   ┌──────────▼────┐ ┌────▼────────┐ ┌▼──────────┐ ┌▼──────────┐
#   │ Direct Answer │ │ Research    │ │ Deep      │ │ Visual    │
#   │ (Fast 20B)    │ │ Swarm       │ │ Analysis  │ │ Pipeline  │
#   └───────────────┘ │ (Parallel)  │ │ (120B)    │ │ (Vision)  │
#                     └──────┬──────┘ └─────┬─────┘ └─────┬─────┘
#                            │              │             │
#   ┌────────────────────────┴──────────────┴─────────────┴──────┐
#   │                    Synthesizer (120B)                      │
#   │          Combine results into coherent response            │
#   └─────────────────────────────────────────────────────────────┘
#
# Run: ruby experiments/multi_model_agents/09_distributed_analyst.rb
# Test: bundle exec rspec spec/experiments/multi_model_agents/09_distributed_analyst_spec.rb

require_relative "../../lib/smolagents"
require_relative "04_tiered_reasoning"
require_relative "05_research_swarm"
require_relative "06_visual_analysis_pipeline"

module Experiments
  module DistributedAnalyst
    # Infrastructure endpoints
    LLAMA_ULTRA = "https://llama-cpp-ultra.reverse-bull.ts.net/v1".freeze
    MACBOOK_PRO = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1".freeze
    MAC_STUDIO = "http://mac-studio.reverse-bull.ts.net:1234/v1".freeze

    # Query classification result
    QueryClassification = Data.define(:category, :confidence, :reasoning) do
      def simple? = category == :simple
      def research? = category == :research
      def analysis? = category == :analysis
      def visual? = category == :visual
    end

    # Comprehensive metrics across all subsystems
    class AnalystMetrics
      attr_reader :classifications, :model_usage, :latencies, :errors

      def initialize
        @classifications = Hash.new(0)
        @model_usage = Hash.new(0)
        @latencies = []
        @errors = []
        @mutex = Mutex.new
      end

      def track_classification(category)
        @mutex.synchronize { @classifications[category] += 1 }
      end

      def track_model(model_id, duration_ms)
        @mutex.synchronize do
          @model_usage[model_id] += 1
          @latencies << { model: model_id, duration_ms: }
        end
      end

      def track_error(error_class, message)
        @mutex.synchronize { @errors << { error_class:, message:, time: Time.now } }
      end

      def summary
        @mutex.synchronize do
          {
            total_queries: @classifications.values.sum,
            classifications: @classifications.to_h,
            model_usage: @model_usage.to_h,
            avg_latency_ms: @latencies.empty? ? 0 : @latencies.sum { |l| l[:duration_ms] } / @latencies.size,
            error_count: @errors.size
          }
        end
      end
    end

    # Model factory for the distributed infrastructure
    module Models
      # Very fast model for triage and simple queries
      def self.fast_triage
        Smolagents.model(:openai)
                  .id("gpt-oss-20b")
                  .timeout(15)
                  .with_health_check(cache_for: 10)
                  .with_retry(max_attempts: 2)
                  .with_fallback { fast_fallback.build }
                  .prefer_healthy
      end

      # Fast model with fallback chain for research workers
      def self.research_worker
        Smolagents.model(:openai)
                  .id("gpt-oss-20b")
                  .timeout(30)
                  .with_health_check(cache_for: 10)
                  .with_retry(max_attempts: 2)
                  .with_fallback { fast_fallback.build }
      end

      # Big model for complex reasoning and synthesis
      def self.reasoning
        Smolagents.model(:openai)
                  .id("gpt-oss-120b")
                  .timeout(120)
                  .with_health_check(cache_for: 30)
                  .with_retry(max_attempts: 2)
                  .with_circuit_breaker(threshold: 3, reset_after: 60)
      end

      # Fallback using Mac Studio
      def self.fast_fallback
        Smolagents.model(:openai)
                  .id("gpt-oss-20b")
                  .timeout(30)
      end
    end

    # Build a classifier agent for query triage
    def self.build_classifier(model:, metrics: nil)
      m = metrics
      Smolagents.agent
                .model { model }
                .tool(:classify, "Classify query type", query: String) do |query:|
                  # Heuristic classification (in production, this would be model-based)
                  category = case query.downcase
                             when /image|photo|picture|visual|diagram|chart/ then :visual
                             when /research|find|search|look up|investigate/ then :research
                             when /analyze|explain|compare|evaluate|assess/ then :analysis
                             else :simple
                             end
                  m&.track_classification(category)
                  QueryClassification.new(
                    category:,
                    confidence: 0.85,
                    reasoning: "Classified based on query keywords"
                  ).to_h.to_s
      end
               .instructions("Classify the query to route to the appropriate handler.")
               .max_steps(3)
               .build
    end

    # Build the synthesizer agent
    def self.build_synthesizer(model:)
      Smolagents.agent
                .model { model }
                .tool(:format_response, "Format final response", content: String) do |content:|
                  content
      end
               .instructions(<<~INST)
                 You synthesize results from multiple sources into a coherent response.
                 - Combine findings without redundancy
                 - Highlight key insights
                 - Note any contradictions
                 - Be concise but comprehensive
               INST
               .max_steps(5)
               .build
    end

    # Build the complete distributed analyst
    #
    # @param triage_model [Model] Model for query classification
    # @param research_model [Model] Model for research workers
    # @param reasoning_model [Model] Model for complex reasoning
    # @param metrics [AnalystMetrics, nil] Optional metrics collector
    # @return [Hash] { coordinator:, metrics:, subsystems: }
    def self.build_analyst(
      triage_model: nil,
      research_model: nil,
      reasoning_model: nil,
      metrics: nil
    )
      collector = metrics || AnalystMetrics.new
      triage = triage_model || Models.fast_triage.build
      research = research_model || Models.research_worker.build
      reasoning = reasoning_model || Models.reasoning.build

      # Build subsystems
      classifier = build_classifier(model: triage, metrics: collector)
      synthesizer = build_synthesizer(model: reasoning)

      # Research swarm with parallel workers
      research_result = ResearchSwarm.build_swarm(
        coordinator_model: research,
        researcher_model: research,
        synthesizer_model: reasoning
      )

      # Visual analysis pipeline
      visual_agent = VisualAnalysisPipeline.build_pipeline(
        reasoning_model: reasoning
      )

      # Build the main coordinator
      coordinator = Smolagents.team
                              .model { triage }
                              .agent(classifier, as: "classifier")
                              .agent(research_result[:team], as: "research_team")
                              .agent(visual_agent, as: "visual_analyzer")
                              .agent(synthesizer, as: "synthesizer")
                              .coordinate(<<~COORD)
                                You are a distributed analyst coordinator.

                                For each query:
                                1. Use classifier to determine query type
                                2. Route to appropriate handler:
                                   - Simple: Answer directly
                                   - Research: Use research_team
                                   - Analysis: Use synthesizer for deep analysis
                                   - Visual: Use visual_analyzer
                                3. Pass results through synthesizer for final response
                              COORD
                              .max_steps(20)
                              .on(:model_generate_completed) do |e|
                                collector.track_model(e.model_id, e.duration_ms)
      end
                             .on(:error) do |e|
                               collector.track_error(e.error_class, e.error_message)
                             end
                             .build

      {
        coordinator:,
        metrics: collector,
        subsystems: {
          classifier:,
          research: research_result,
          visual: visual_agent,
          synthesizer:
        }
      }
    end

    # Build for testing with mock models
    def self.build_for_testing(
      triage_responses:,
      research_responses: {},
      reasoning_responses: []
    )
      triage_model = Smolagents::Testing::MockModel.new(model_id: "mock-triage")
      triage_responses.each { |r| triage_model.queue_response(r) }

      research_model = Smolagents::Testing::MockModel.new(model_id: "mock-research")
      (research_responses[:coordinator] || []).each { |r| research_model.queue_response(r) }

      reasoning_model = Smolagents::Testing::MockModel.new(model_id: "mock-reasoning")
      reasoning_responses.each { |r| reasoning_model.queue_response(r) }

      metrics = AnalystMetrics.new

      result = build_analyst(
        triage_model:,
        research_model:,
        reasoning_model:,
        metrics:
      )

      result.merge(
        models: {
          triage: triage_model,
          research: research_model,
          reasoning: reasoning_model
        }
      )
    end
  end
end

# =============================================================================
# DEMO
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Distributed Analyst Experiment"
  puts "=" * 50
  puts
  puts "This is a comprehensive agent that demonstrates:"
  puts "1. Query classification and intelligent routing"
  puts "2. Tiered model usage (fast vs powerful)"
  puts "3. Parallel research with result synthesis"
  puts "4. Visual analysis pipeline integration"
  puts "5. Resilience with fallbacks and circuit breakers"
  puts "6. Comprehensive metrics across all subsystems"
  puts
  puts "Architecture:"
  puts "  User Query → Classifier → [Simple|Research|Analysis|Visual] → Synthesizer"
  puts
  puts "Infrastructure:"
  puts "  - LLaMA Ultra: Triage (very fast 20B)"
  puts "  - MacBook Pro: Research workers (fast 20B) + Reasoning (120B)"
  puts "  - Mac Studio: Fallback capacity (20B)"
  puts
  puts "To test:"
  puts "  bundle exec rspec spec/experiments/multi_model_agents/09_distributed_analyst_spec.rb"
end
