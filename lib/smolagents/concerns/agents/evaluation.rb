module Smolagents
  module Concerns
    # Structured evaluation phase for agent metacognition.
    #
    # After each action step, the evaluation phase checks if the goal has been achieved.
    # This is a lightweight, scoped model call - not a full agent - designed for
    # token efficiency while providing structured decision-making.
    #
    # == Why Evaluation Matters
    #
    # Models often "forget" to call final_answer even when they have the result.
    # The evaluation phase provides structured metacognition:
    # - Task + last observation → "Is this done?"
    # - If yes → extract answer and finalize
    # - If no → continue with optional guidance
    #
    # == Token Efficiency
    #
    # - Minimal context: only task + last observation (not full history)
    # - Short prompt: ~50 tokens
    # - Limited response: max_tokens: 100
    # - Only runs when model didn't call final_answer
    #
    # @example Enabling evaluation
    #   agent = Smolagents.agent
    #     .model { m }
    #     .evaluation(enabled: true)
    #     .build
    #
    # @see Types::EvaluationResult The result type
    # @see ReActLoop::Execution Where evaluation is called
    module Evaluation
      # System prompt for evaluation - minimal, focused.
      EVALUATION_SYSTEM = <<~PROMPT.strip.freeze
        You evaluate task completion. Be decisive. One line only.
      PROMPT

      # User prompt template - scoped context only.
      EVALUATION_PROMPT = <<~PROMPT.freeze
        TASK: %<task>s
        STEPS COMPLETED: %<step_count>d
        LAST RESULT: %<observation>s

        Is the task complete? Reply with EXACTLY one of:
        DONE: <the final answer>
        CONTINUE: <what's still needed>
        STUCK: <what's blocking>
      PROMPT

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

          # Token-limited call - we only need a short structured answer
          response = @model.generate(messages, max_tokens: 100)
          parse_evaluation(response.content, response.token_usage)
        end
      end

      def extract_observation(step)
        obs = step.observations || step.action_output.to_s
        obs.to_s.slice(0, 500) # Truncate for token efficiency
      end

      def build_evaluation_messages(task, step_count, observation)
        [
          ChatMessage.system(EVALUATION_SYSTEM),
          ChatMessage.user(format(EVALUATION_PROMPT, task:, step_count:, observation:))
        ]
      end

      # Parses the evaluation response using pattern matching.
      #
      # @param content [String] Raw model response
      # @param token_usage [TokenUsage, nil] Tokens used
      # @return [EvaluationResult]
      def parse_evaluation(content, token_usage = nil)
        case content.strip
        when /\ADONE:\s*(.+)/mi
          Types::EvaluationResult.achieved(answer: ::Regexp.last_match(1).strip, token_usage:)
        when /\ACONTINUE:\s*(.+)/mi
          Types::EvaluationResult.continue(reasoning: ::Regexp.last_match(1).strip, token_usage:)
        when /\ASTUCK:\s*(.+)/mi
          Types::EvaluationResult.stuck(reasoning: ::Regexp.last_match(1).strip, token_usage:)
        else
          # Default to continue if response format unclear
          Types::EvaluationResult.continue(reasoning: content.strip, token_usage:)
        end
      end

      # Executes evaluation phase after a step if enabled.
      #
      # Only runs if:
      # 1. Evaluation is enabled
      # 2. The step didn't already call final_answer
      #
      # @param task [String] The original task
      # @param step [ActionStep] The step just executed
      # @param step_count [Integer] Number of steps so far
      # @yield [EvaluationResult] The result if evaluation ran
      # @return [EvaluationResult, nil] Result or nil if skipped
      def execute_evaluation_if_needed(task, step, step_count)
        return nil unless @evaluation_enabled
        return nil if step.is_final_answer # Already done

        result = evaluate_progress(task, step, step_count)
        record_evaluation_to_context(result)
        emit_evaluation_event(result, step_count)
        log_evaluation_result(result, step_count)
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
               token_usage: result.token_usage
             ))
      end

      def log_evaluation_result(result, step_count)
        case result.status
        when :goal_achieved
          @logger.info("Evaluation: goal achieved", step: step_count, answer: result.answer&.slice(0, 50))
        when :stuck
          @logger.warn("Evaluation: stuck", step: step_count, reason: result.reasoning&.slice(0, 50))
        else
          @logger.debug("Evaluation: continue", step: step_count, reason: result.reasoning&.slice(0, 50))
        end
      end
    end
  end
end
