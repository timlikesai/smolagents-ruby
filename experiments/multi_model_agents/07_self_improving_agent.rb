# Experiment: Self-Improving Agent
#
# Agent that learns from failures, refines approaches, and maintains knowledge.
# Demonstrates metacognition events and the self-refinement loop.
#
# Learning Loop:
#   Task -> Execute -> Evaluate -> Reflect -> Store Learning -> Apply to Future Tasks
#
# Key Features:
#   - Self-evaluation after each task
#   - Reflection on failures
#   - Knowledge accumulation
#   - Strategy adaptation
#   - Event-driven progress tracking via :step_completed and :task_lifecycle
#
# Run: ruby experiments/multi_model_agents/07_self_improving_agent.rb
# Test: bundle exec rspec spec/experiments/multi_model_agents/07_self_improving_agent_spec.rb

require_relative "../../lib/smolagents"

module Experiments
  module SelfImprovingAgent
    # Knowledge entry for the learning system
    Learning = Data.define(:task_type, :outcome, :reflection, :strategy_update, :timestamp) do
      def self.from_reflection(task_type:, outcome:, reflection:)
        strategy = case outcome
                   when :success then "Continue with current approach"
                   when :failure then "Adjust: #{reflection}"
                   when :partial then "Refine: #{reflection}"
                   else "Review needed"
                   end

        new(task_type:, outcome:, reflection:, strategy_update: strategy, timestamp: Time.now)
      end

      def applicable_to?(task_description) = task_description.downcase.include?(task_type.downcase)
    end

    # Simple in-memory knowledge base
    class KnowledgeBase
      attr_reader :learnings, :strategies

      def initialize
        @learnings = []
        @strategies = Hash.new { |h, k| h[k] = [] }
      end

      def store(learning)
        @learnings << learning
        @strategies[learning.task_type] << learning.strategy_update
      end

      def relevant_learnings(task_description, limit: 3)
        @learnings
          .select { |l| l.applicable_to?(task_description) }
          .last(limit)
      end

      def strategy_hints(task_type) = @strategies[task_type].last(3).join("\n- ")

      def summary
        {
          total_learnings: @learnings.size,
          by_outcome: @learnings.group_by(&:outcome).transform_values(&:size),
          task_types: @strategies.keys
        }
      end
    end

    # Metrics for the self-improvement loop
    class ImprovementMetrics
      attr_reader :evaluations, :refinements, :reflections, :steps, :completions

      def initialize
        @evaluations = []
        @refinements = []
        @reflections = []
        @steps = []
        @completions = []
      end

      def track_evaluation(event)
        @evaluations << {
          step: event.step_number,
          status: event.status,
          confidence: event.confidence,
          reasoning: event.reasoning
        }
      end

      def track_refinement(event)
        @refinements << {
          iterations: event.iterations,
          improved: event.improved,
          confidence: event.confidence
        }
      end

      def track_reflection(event)
        @reflections << {
          outcome: event.outcome,
          reflection: event.reflection
        }
      end

      def track_step(event)
        @steps << {
          step_number: event.step_number,
          outcome: event.outcome,
          observations: event.observations
        }
      end

      def track_completion(event)
        @completions << {
          outcome: event.outcome,
          output: event.output,
          steps_taken: event.steps_taken
        }
      end

      def improvement_rate
        return 0 if @refinements.empty?

        @refinements.count { |r| r[:improved] }.to_f / @refinements.size
      end

      def average_confidence
        return 0 if @evaluations.empty?

        @evaluations.sum { |e| e[:confidence] || 0 } / @evaluations.size.to_f
      end

      def summary
        {
          total_evaluations: @evaluations.size,
          total_refinements: @refinements.size,
          total_reflections: @reflections.size,
          total_steps: @steps.size,
          total_completions: @completions.size,
          improvement_rate: (improvement_rate * 100).round(1),
          average_confidence: (average_confidence * 100).round(1)
        }
      end
    end

    # Build a self-improving agent
    #
    # @param execution_model [Model] Model for task execution
    # @param evaluation_model [Model] Model for self-evaluation (can be larger)
    # @param knowledge_base [KnowledgeBase] Optional knowledge base
    # @param metrics [ImprovementMetrics] Optional metrics collector
    # @return [Hash] { agent:, knowledge_base:, metrics: }
    def self.build_improving_agent(execution_model:, evaluation_model: nil, knowledge_base: nil, metrics: nil)
      kb = knowledge_base || KnowledgeBase.new
      collector = metrics || ImprovementMetrics.new
      eval_model = evaluation_model || execution_model

      agent = Smolagents.agent
                        .model(:execution) { execution_model }
                        .model(:evaluation) { eval_model }
                        .tool(:search, "Search for information", query: String) { |query:| "Results for: #{query}" }
                        .tool(:calculate, "Calculate expression", expr: String) { |expr:| "42" }
                        .tool(:analyze, "Analyze data", data: String) { |data:| "Analysis of: #{data}" }
                        .evaluation(enabled: true)
                        .refine(max_iterations: 3, min_confidence: 0.75)
                        .planning(interval: 5)
                        .instructions(<<~INST)
                          You are a self-improving agent that learns from experience.

                          Before each task:
                          - Consider what you've learned from similar tasks
                          - Apply relevant strategies from past experience

                          During execution:
                          - Monitor your own progress
                          - Adjust approach if hitting obstacles

                          After completion:
                          - Reflect on what worked and what didn't
                          - Note strategies for future similar tasks
                        INST
                        .max_steps(15)
                        # Track progress events
                        .on(:step_completed) { |e| collector.track_step(e) }
                        .on(:task_lifecycle) { |e| collector.track_completion(e) if e.completed? }
                        # Track metacognition events
                        .on(:evaluation_completed) { |e| collector.track_evaluation(e) }
                        .on(:refinement) { |e| collector.track_refinement(e) if e.completed? }
                        .on(:reflection_recorded) do |e|
                          collector.track_reflection(e)
                          # Store learning in knowledge base
                          learning = Learning.from_reflection(
                            task_type: "general",
                            outcome: e.outcome,
                            reflection: e.reflection
                          )
                          kb.store(learning)
                        end
                        # Track drift and repetition
                        .on(:drift_detected) { |e| puts "[DRIFT] Level: #{e.level}, Relevance: #{e.task_relevance}" }
                        .on(:repetition_detected) { |e| puts "[LOOP] Pattern: #{e.pattern}, Count: #{e.count}" }
                        .build

      { agent:, knowledge_base: kb, metrics: collector }
    end

    # Wrapper that injects prior learnings into task context
    class LearningAgent
      def initialize(agent:, knowledge_base:, metrics:)
        @agent = agent
        @kb = knowledge_base
        @metrics = metrics
      end

      def run(task)
        # Enhance task with relevant prior learnings
        relevant = @kb.relevant_learnings(task)
        enhanced_task = if relevant.any?
                          <<~TASK
                            #{task}

                            PRIOR LEARNINGS (from similar tasks):
                            #{relevant.map { |l| "- #{l.reflection}" }.join("\n")}
                          TASK
                        else
                          task
                        end

        @agent.run(enhanced_task)
      end

      def knowledge_summary = @kb.summary
      def improvement_summary = @metrics.summary
    end

    # Build for testing with mock models
    def self.build_for_testing(
      execution_responses:,
      evaluation_responses: [],
      initial_learnings: []
    )
      execution_model = Smolagents::Testing::MockModel.new(model_id: "mock-execution")
      execution_responses.each { |r| execution_model.queue_response(r) }

      evaluation_model = Smolagents::Testing::MockModel.new(model_id: "mock-evaluation")
      evaluation_responses.each { |r| evaluation_model.queue_response(r) }

      kb = KnowledgeBase.new
      initial_learnings.each { |l| kb.store(l) }

      metrics = ImprovementMetrics.new

      agent = Smolagents.agent
                        .model(:execution) { execution_model }
                        .model(:evaluation) { evaluation_model }
                        .tool(:search, "Search", query: String) { |query:| "Results: #{query}" }
                        .tool(:calculate, "Calculate", expr: String) { |expr:| "42" }
                        .evaluation(enabled: true)
                        .refine(max_iterations: 2, min_confidence: 0.7)
                        .max_steps(8)
                        .on(:step_completed) { |e| metrics.track_step(e) }
                        .on(:task_lifecycle) { |e| metrics.track_completion(e) if e.completed? }
                        .on(:evaluation_completed) { |e| metrics.track_evaluation(e) }
                        .on(:refinement) { |e| metrics.track_refinement(e) if e.completed? }
                        .on(:reflection_recorded) do |e|
                          metrics.track_reflection(e)
                          learning = Learning.from_reflection(
                            task_type: "test",
                            outcome: e.outcome,
                            reflection: e.reflection
                          )
                          kb.store(learning)
                        end
                        .build

      {
        agent: LearningAgent.new(agent:, knowledge_base: kb, metrics:),
        raw_agent: agent,
        models: { execution: execution_model, evaluation: evaluation_model },
        knowledge_base: kb,
        metrics:
      }
    end
  end
end

# =============================================================================
# DEMO
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Self-Improving Agent Experiment"
  puts "=" * 40
  puts
  puts "This experiment demonstrates:"
  puts "1. Self-evaluation with confidence scoring"
  puts "2. Self-refinement loop (arXiv:2303.17651)"
  puts "3. Reflection storage and retrieval"
  puts "4. Learning accumulation across tasks"
  puts "5. Event-driven progress and completion tracking"
  puts
  puts "Key events monitored:"
  puts "  - :step_completed   -> track progress through execution"
  puts "  - :task_lifecycle   -> track task outcomes and results"
  puts "  - :evaluation_completed -> track confidence and status"
  puts "  - :refinement       -> track improvement iterations"
  puts "  - :reflection_recorded -> capture learnings"
  puts "  - :drift_detected   -> detect off-track behavior"
  puts "  - :repetition_detected -> break out of loops"
  puts
  puts "To test:"
  puts "  bundle exec rspec spec/experiments/multi_model_agents/07_self_improving_agent_spec.rb"
end
