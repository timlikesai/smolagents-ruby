module Smolagents
  module Types
    # Represents a single turn in a multi-turn conversation.
    #
    # Each turn captures the task, steps taken, token usage, and timing
    # for one invocation of the agent's ReAct loop.
    #
    # @!attribute [r] turn_number [Integer] Turn index (0-based)
    # @!attribute [r] task [String] The task for this turn
    # @!attribute [r] steps [Array] Steps taken during this turn
    # @!attribute [r] token_usage [TokenUsage, nil] Tokens consumed
    # @!attribute [r] timing [Timing, nil] Duration of this turn
    #
    # @example
    #   turn = ConversationTurn.create(turn_number: 0, task: "Hello")
    #   turn.turn_number  #=> 0
    ConversationTurn = Data.define(:turn_number, :task, :steps, :token_usage, :timing) do
      def self.create(turn_number:, task:, steps: [], token_usage: nil, timing: nil)
        new(turn_number:, task:, steps: steps.freeze, token_usage:, timing:)
      end

      def step_count = steps.count
      def duration = timing&.duration
      def deconstruct_keys(_) = { turn_number:, task:, steps:, token_usage:, timing: }
    end
  end
end
