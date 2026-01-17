module Smolagents
  module Types
    # Valid evaluation statuses
    EVALUATION_STATUSES = %i[goal_achieved continue stuck].freeze

    # Result of an evaluation phase during agent execution.
    #
    # The evaluation phase checks if the agent has achieved its goal after each step,
    # allowing structured metacognition without relying on the model to call final_answer.
    #
    # @example Pattern matching on result
    #   case evaluate_progress(task, step)
    #   in EvaluationResult[status: :goal_achieved, answer:]
    #     finalize(:success, answer)
    #   in EvaluationResult[status: :continue]
    #     # Keep going
    #   in EvaluationResult[status: :stuck, reasoning:]
    #     inject_guidance(reasoning)
    #   end
    #
    # @see Concerns::Evaluation The evaluation concern
    EvaluationResult = Data.define(:status, :answer, :reasoning, :token_usage) do
      # Whether the goal has been achieved.
      # @return [Boolean]
      def goal_achieved? = status == :goal_achieved

      # Whether the agent should continue.
      # @return [Boolean]
      def continue? = status == :continue

      # Whether the agent is stuck and needs guidance.
      # @return [Boolean]
      def stuck? = status == :stuck

      class << self
        # Creates a result indicating goal achievement.
        #
        # @param answer [Object] The achieved result
        # @param token_usage [TokenUsage, nil] Tokens used for evaluation
        # @return [EvaluationResult]
        def achieved(answer:, token_usage: nil)
          new(status: :goal_achieved, answer:, reasoning: nil, token_usage:)
        end

        # Creates a result indicating continuation is needed.
        #
        # @param reasoning [String, nil] Why we should continue
        # @param token_usage [TokenUsage, nil] Tokens used for evaluation
        # @return [EvaluationResult]
        def continue(reasoning: nil, token_usage: nil)
          new(status: :continue, answer: nil, reasoning:, token_usage:)
        end

        # Creates a result indicating the agent is stuck.
        #
        # @param reasoning [String] What's blocking progress
        # @param token_usage [TokenUsage, nil] Tokens used for evaluation
        # @return [EvaluationResult]
        def stuck(reasoning:, token_usage: nil)
          new(status: :stuck, answer: nil, reasoning:, token_usage:)
        end
      end
    end
  end
end
