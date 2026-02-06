require_relative "evaluation/protocol"
require_relative "evaluation/parsing"

module Smolagents
  module Concerns
    # Structured evaluation phase for agent metacognition.
    #
    # After each step, checks goal achievement via a lightweight model call.
    # Token-efficient: minimal context (task + observation), ~50 tokens, max_tokens: 100.
    #
    # @example Enabling evaluation
    #   agent = Smolagents.agent.model { m }.evaluation(enabled: true).build
    #
    # @see Types::EvaluationResult The result type
    # @see Evaluation::Protocol For prompts and step interface
    # @see Evaluation::Parsing For response parsing
    module Evaluation
      include Evaluation::Protocol
      include Evaluation::Parsing

      def self.included(base)
        base.attr_reader :evaluation_enabled
      end

      private

      def initialize_evaluation(evaluation_enabled: true)
        @evaluation_enabled = evaluation_enabled
      end

      # Evaluates whether the current step achieved the goal.
      #
      # This is a scoped model call with minimal context - just the task
      # and last observation. Token-efficient by design.
      #
      # @param task [String] The original task
      # @param step [ActionStep] The step just executed
      # @param step_count [Integer] Number of steps so far
      # @return [EvaluationResult] The evaluation outcome
      def evaluate_progress(task, step, step_count)
        Telemetry::Instrumentation.instrument("smolagents.evaluation", step_count:) do
          observation = extract_observation(step)
          messages = build_evaluation_messages(task, step_count, observation)

          # Token-limited but allow enough for actual answer content
          response = @model.generate(messages, max_tokens: 300)
          parse_evaluation(response.content, response.token_usage)
        end
      end

      # Executes evaluation phase after a step if enabled.
      #
      # Only runs if:
      # 1. Evaluation is enabled
      # 2. The step didn't already call final_answer
      #
      # @param task [String] The original task
      # @param step [#final_answer?] The step just executed
      # @param step_count [Integer] Number of steps so far
      # @yield [EvaluationResult] The result if evaluation ran
      # @return [EvaluationResult, nil] Result or nil if skipped
      def execute_evaluation_if_needed(task, step, step_count)
        return nil unless @evaluation_enabled
        return nil if step_is_final_answer?(step)

        result = evaluate_progress(task, step, step_count)
        record_evaluation_to_context(result)
        emit_evaluation_event(result, step_count)
        yield result if block_given?
        result
      end

      def record_evaluation_to_context(result)
        ctx = Types::ObservabilityContext.current
        return unless ctx

        ctx.add_tokens(result.token_usage)
        ctx.record_evaluation(result)
      end

      def emit_evaluation_event(result, step_count)
        emit(Events::EvaluationCompleted.create(
               step_number: step_count,
               status: result.status,
               answer: result.answer,
               reasoning: result.reasoning,
               confidence: result.confidence,
               token_usage: result.token_usage
             ))
      end
    end
  end
end
