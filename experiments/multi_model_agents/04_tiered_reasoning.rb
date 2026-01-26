# Experiment: Tiered Reasoning Agent
#
# Uses fast models for quick decisions, escalates to larger models for complex reasoning.
# Demonstrates multi-model orchestration and event-driven monitoring.
#
# Infrastructure:
#   - Fast (20B): llama-ultra, macbook-pro (very fast)
#   - Big (120B): macbook-pro only (fairly fast)
#
# Run: ruby experiments/multi_model_agents/04_tiered_reasoning.rb
# Test: bundle exec rspec spec/experiments/multi_model_agents/04_tiered_reasoning_spec.rb

require_relative "../../lib/smolagents"

module Experiments
  module TieredReasoning
    # Infrastructure endpoints
    LLAMA_ULTRA = "https://llama-cpp-ultra.reverse-bull.ts.net/v1".freeze
    MACBOOK_PRO = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1".freeze
    MAC_STUDIO = "http://mac-studio.reverse-bull.ts.net:1234/v1".freeze

    # Model factory methods for the distributed infrastructure
    module Models
      # Very fast 20B model on llama-ultra (GPU accelerated)
      def self.fast_20b
        Smolagents.model(:openai)
                  .base_url(LLAMA_ULTRA)
                  .id("gpt-oss-20b-MXFP4")
                  .timeout(30)
                  .with_health_check(cache_for: 10, verify_model: true)
                  .with_retry(max_attempts: 2, backoff: :exponential)
      end

      # Bigger 30B model on llama-ultra for complex reasoning
      def self.big_30b
        Smolagents.model(:openai)
                  .base_url(LLAMA_ULTRA)
                  .id("Qwen3-Coder-30B-A3B-Instruct-MXFP4_MOE")
                  .timeout(120) # Slower, needs more time
                  .with_health_check(cache_for: 30, verify_model: true)
                  .with_retry(max_attempts: 2)
      end

      # Fast 20B with geographic fallback chain
      def self.fast_20b_resilient
        fast_20b
          .with_fallback { Smolagents.model(:openai).base_url(MAC_STUDIO).id("openai/gpt-oss-20b").timeout(30).build }
          .with_fallback { Smolagents.model(:openai).base_url(MACBOOK_PRO).id("glm-4.7-flash-mlx@8bit").timeout(30).build }
          .with_circuit_breaker(threshold: 3, reset_after: 60)
          .prefer_healthy
      end
    end

    # Metrics collector for observability
    class MetricsCollector
      attr_reader :model_calls, :failovers, :step_timings

      def initialize
        @model_calls = Hash.new(0)
        @failovers = []
        @step_timings = []
      end

      def track_model_call(event)
        @model_calls[event.model_id] += 1
      end

      def track_failover(event)
        @failovers << {
          from: event.from_model_id,
          to: event.to_model_id,
          error: event.error_class
        }
      end

      def track_step(event)
        @step_timings << {
          step: event.step_number,
          outcome: event.outcome
        }
      end

      def summary
        {
          total_calls: @model_calls.values.sum,
          calls_by_model: @model_calls.to_h,
          failover_count: @failovers.size,
          steps_completed: @step_timings.size
        }
      end
    end

    # Build a tiered reasoning agent
    #
    # @param fast_model [Model] Fast model for triage and simple execution
    # @param big_model [Model] Large model for complex reasoning
    # @param metrics [MetricsCollector] Optional metrics collector
    # @return [Agent] Configured agent
    def self.build_tiered_agent(fast_model: nil, big_model: nil, metrics: nil)
      fast = fast_model || Models.fast_20b_resilient.build
      big = big_model || Models.big_30b.build
      collector = metrics || MetricsCollector.new

      Smolagents.agent
                .model(:execution) { fast }
                .model(:planning) { big } # Use big model for planning
                .model(:evaluation) { fast } # Quick evaluation
                .tool(:search, "Search for information", query: String) { |query:| "Results for: #{query}" }
                .tool(:calculate, "Calculate expression", expr: String) { |expr:| eval(expr).to_s }
                .planning(interval: 5) # Replan every 5 steps with big model
                .evaluation(enabled: true)
                .refine(max_iterations: 2, min_confidence: 0.7)
                .max_steps(20)
                .instructions(<<~INSTRUCTIONS)
                  You are a tiered reasoning agent.

                  For SIMPLE tasks (lookup, calculation, formatting):
                  - Execute directly and quickly
                  - Don't overthink

                  For COMPLEX tasks (analysis, synthesis, multi-step reasoning):
                  - Break down into steps
                  - Verify each step before proceeding
                  - Use planning to organize your approach

                  Always prefer efficiency - use the simplest approach that works.
                INSTRUCTIONS
                .on(:model_generate_completed) { |e| collector.track_model_call(e) }
                .on(:failover) { |e| collector.track_failover(e) }
                .on(:step_complete) { |e| collector.track_step(e) }
                .build
    end

    # Build for testing with mock models
    def self.build_for_testing(triage_responses:, execution_responses:, planning_responses: [])
      triage_model = Smolagents::Testing::MockModel.new(model_id: "mock-triage")
      triage_responses.each { |r| triage_model.queue_response(r) }

      execution_model = Smolagents::Testing::MockModel.new(model_id: "mock-execution")
      execution_responses.each { |r| execution_model.queue_response(r) }

      planning_model = Smolagents::Testing::MockModel.new(model_id: "mock-planning")
      planning_responses.each { |r| planning_model.queue_response(r) }

      metrics = MetricsCollector.new

      agent = Smolagents.agent
                        .model(:execution) { execution_model }
                        .model(:planning) { planning_model.call_count.zero? ? execution_model : planning_model }
                        .model(:evaluation) { triage_model }
                        .tool(:search, "Search", query: String) { |query:| "Results: #{query}" }
                        .tool(:calculate, "Calculate", expr: String) { |expr:| "42" }
                        .max_steps(10)
                        .on(:model_generate_completed) { |e| metrics.track_model_call(e) }
                        .on(:step_complete) { |e| metrics.track_step(e) }
                        .build

      { agent:, models: { triage: triage_model, execution: execution_model, planning: planning_model }, metrics: }
    end
  end
end

# =============================================================================
# DEMO
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Tiered Reasoning Agent Experiment"
  puts "=" * 40
  puts
  puts "This experiment demonstrates:"
  puts "1. Multi-model routing (fast vs big)"
  puts "2. Resilient fallback chains"
  puts "3. Event-driven metrics collection"
  puts
  puts "To test with mock models:"
  puts "  bundle exec rspec spec/experiments/multi_model_agents/04_tiered_reasoning_spec.rb"
  puts
  puts "To run with real infrastructure:"
  puts "  # Ensure your model servers are running, then:"
  puts "  agent = Experiments::TieredReasoning.build_tiered_agent"
  puts "  result = agent.run('Analyze the trade-offs between Ruby and Python for ML')"
end
