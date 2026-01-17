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
    # == Step Protocol
    #
    # Steps passed to evaluation must implement the EvaluableStep protocol:
    # - +evaluation_observation+ → String observation text for evaluation
    # - +final_answer?+ → Boolean indicating if step completed the task
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
      # Includes optional confidence for AgentPRM-style scoring.
      EVALUATION_PROMPT = <<~PROMPT.freeze
        TASK: %<task>s
        STEPS COMPLETED: %<step_count>d
        LAST RESULT: %<observation>s

        Is the task complete? Reply with EXACTLY one of:
        DONE: <the final answer>
        CONTINUE: <what's still needed>
        STUCK: <what's blocking>

        Optionally add confidence (0.0-1.0): CONFIDENCE: 0.8
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

      # Extracts observation text from step using the EvaluableStep protocol.
      #
      # Steps implementing +evaluation_observation+ get that value directly.
      # Falls back to +observations+ or +action_output+ for legacy compatibility.
      #
      # @param step [#evaluation_observation, #observations, #action_output] The step
      # @return [String] Observation text (truncated to 500 chars)
      def extract_observation(step)
        obs = if step.respond_to?(:evaluation_observation)
                step.evaluation_observation
              elsif step.respond_to?(:observations)
                step.observations || step.action_output.to_s
              else
                step.to_s
              end
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
      # Extracts status, content, and optional confidence from model response.
      # Confidence defaults to AgentPRM-style values if not provided.
      #
      # @param content [String] Raw model response
      # @param token_usage [TokenUsage, nil] Tokens used
      # @return [EvaluationResult]
      def parse_evaluation(content, token_usage = nil)
        text = content.strip
        confidence = extract_confidence(text)
        parse_evaluation_text(text, confidence, token_usage)
      end

      def parse_evaluation_text(text, confidence, token_usage)
        case text
        when /\ADONE:\s*(.+?)(?:\nCONFIDENCE:|$)/mi
          build_evaluation_result(:goal_achieved, answer: ::Regexp.last_match(1).strip, confidence:, token_usage:)
        when /\ACONTINUE:\s*(.+?)(?:\nCONFIDENCE:|$)/mi
          build_evaluation_result(:continue, reasoning: ::Regexp.last_match(1).strip, confidence:, token_usage:)
        when /\ASTUCK:\s*(.+?)(?:\nCONFIDENCE:|$)/mi
          build_evaluation_result(:stuck, reasoning: ::Regexp.last_match(1).strip, confidence:, token_usage:)
        else
          Types::EvaluationResult.continue(reasoning: text, confidence: 0.3, token_usage:)
        end
      end

      def build_evaluation_result(status, answer: nil, reasoning: nil, confidence: nil, token_usage: nil)
        opts = { token_usage: }
        opts[:confidence] = confidence if confidence

        case status
        when :goal_achieved
          Types::EvaluationResult.achieved(answer:, **opts)
        when :continue
          Types::EvaluationResult.continue(reasoning:, **opts)
        when :stuck
          Types::EvaluationResult.stuck(reasoning:, **opts)
        end
      end

      # Extracts confidence score from evaluation response if present.
      #
      # @param text [String] Raw model response
      # @return [Float, nil] Confidence score or nil for default
      def extract_confidence(text)
        return nil unless text =~ /CONFIDENCE:\s*([\d.]+)/i

        confidence = ::Regexp.last_match(1).to_f
        confidence.clamp(0.0, 1.0)
      end

      # Executes evaluation phase after a step if enabled.
      #
      # Only runs if:
      # 1. Evaluation is enabled
      # 2. The step didn't already call final_answer
      #
      # Uses the EvaluableStep protocol to check completion:
      # - +final_answer?+ preferred (protocol method)
      # - Falls back to +is_final_answer+ for ActionStep compatibility
      #
      # @param task [String] The original task
      # @param step [#final_answer?, #is_final_answer] The step just executed
      # @param step_count [Integer] Number of steps so far
      # @yield [EvaluationResult] The result if evaluation ran
      # @return [EvaluationResult, nil] Result or nil if skipped
      def execute_evaluation_if_needed(task, step, step_count)
        return nil unless @evaluation_enabled
        return nil if step_is_final_answer?(step)

        result = evaluate_progress(task, step, step_count)
        record_evaluation_to_context(result)
        emit_evaluation_event(result, step_count)
        log_evaluation_result(result, step_count)
        yield result if block_given?
        result
      end

      # Checks if step is a final answer using the EvaluableStep protocol.
      #
      # @param step [#final_answer?, #is_final_answer] The step to check
      # @return [Boolean] True if step represents task completion
      def step_is_final_answer?(step)
        if step.respond_to?(:final_answer?)
          step.final_answer?
        elsif step.respond_to?(:is_final_answer)
          step.is_final_answer
        else
          false
        end
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
