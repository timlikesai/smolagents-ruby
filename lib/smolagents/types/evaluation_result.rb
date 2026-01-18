module Smolagents
  module Types
    # Valid evaluation statuses matching AgentPRM "promise/progress" scoring.
    # @see https://arxiv.org/abs/2511.08325 AgentPRM paper
    EVALUATION_STATUSES = %i[goal_achieved continue stuck].freeze

    # Default confidence levels for each status.
    # Based on research: high confidence for done, medium for continue, low for stuck.
    DEFAULT_CONFIDENCE = {
      goal_achieved: 0.9,
      continue: 0.5,
      stuck: 0.3
    }.freeze

    # Result of an evaluation phase during agent execution.
    #
    # The evaluation phase checks if the agent has achieved its goal after each step,
    # allowing structured metacognition without relying on the model to call final_answer.
    #
    # Confidence scores follow AgentPRM "promise/progress" patterns:
    # - goal_achieved: High confidence (0.9) - we're done
    # - continue: Medium confidence (0.5) - making progress
    # - stuck: Low confidence (0.3) - needs intervention
    #
    # @example Pattern matching on result
    #   case evaluate_progress(task, step)
    #   in EvaluationResult[status: :goal_achieved, answer:, confidence:] if confidence > 0.8
    #     finalize(:success, answer)
    #   in EvaluationResult[status: :continue, confidence:] if confidence < 0.3
    #     inject_guidance("Low confidence - reconsider approach")
    #   in EvaluationResult[status: :stuck, reasoning:]
    #     inject_guidance(reasoning)
    #   end
    #
    # @see Concerns::Evaluation The evaluation concern
    # @see https://arxiv.org/abs/2511.08325 AgentPRM paper on promise/progress scoring
    EvaluationResult = Data.define(:status, :answer, :reasoning, :confidence, :token_usage) do
      include TypeSupport::Deconstructable
      include TypeSupport::StatePredicates
      extend TypeSupport::FactoryBuilder

      # State predicates for evaluation statuses
      state_predicates :status,
                       goal_achieved: :goal_achieved,
                       continue: :continue,
                       stuck: :stuck

      # Whether confidence is high enough to trust the result.
      # @param threshold [Float] Minimum confidence threshold (default: 0.7)
      # @return [Boolean]
      def confident?(threshold: 0.7)
        (confidence || 0.0) >= threshold
      end

      # Whether this result indicates low confidence requiring attention.
      # @param threshold [Float] Maximum confidence for "low" (default: 0.4)
      # @return [Boolean]
      def low_confidence?(threshold: 0.4)
        (confidence || 0.0) < threshold
      end

      class << self
        # Creates a result indicating goal achievement.
        #
        # @param answer [Object] The achieved result
        # @param confidence [Float] Confidence level (0.0-1.0, default: 0.9)
        # @param token_usage [TokenUsage, nil] Tokens used for evaluation
        # @return [EvaluationResult]
        def achieved(answer:, confidence: DEFAULT_CONFIDENCE[:goal_achieved], token_usage: nil)
          new(status: :goal_achieved, answer:, reasoning: nil, confidence:, token_usage:)
        end

        # Creates a result indicating continuation is needed.
        #
        # @param reasoning [String, nil] Why we should continue
        # @param confidence [Float] Confidence in progress (0.0-1.0, default: 0.5)
        # @param token_usage [TokenUsage, nil] Tokens used for evaluation
        # @return [EvaluationResult]
        def continue(reasoning: nil, confidence: DEFAULT_CONFIDENCE[:continue], token_usage: nil)
          new(status: :continue, answer: nil, reasoning:, confidence:, token_usage:)
        end

        # Creates a result indicating the agent is stuck.
        #
        # @param reasoning [String] What's blocking progress
        # @param confidence [Float] Confidence we're truly stuck (0.0-1.0, default: 0.3)
        # @param token_usage [TokenUsage, nil] Tokens used for evaluation
        # @return [EvaluationResult]
        def stuck(reasoning:, confidence: DEFAULT_CONFIDENCE[:stuck], token_usage: nil)
          new(status: :stuck, answer: nil, reasoning:, confidence:, token_usage:)
        end
      end
    end
  end
end
