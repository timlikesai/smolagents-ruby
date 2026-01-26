module Smolagents
  module Types
    # Immutable step representing planning/reasoning output.
    #
    # PlanningStep captures the agent's planning phase, including input
    # messages that prompted planning and the resulting plan. Planning steps
    # occur at the start of execution and periodically during long runs.
    #
    # @example Creating a planning step
    #   step = Types::PlanningStep.new(
    #     model_input_messages: [ChatMessage.system("Plan the task...")],
    #     model_output_message: ChatMessage.assistant("1. Search...\n2. Analyze..."),
    #     plan: "1. Search...\n2. Analyze...",
    #     timing: Timing.new(start_time: t1, end_time: t2),
    #     token_usage: TokenUsage.new(input_tokens: 50, output_tokens: 100)
    #   )
    #
    # @see Concerns::Planning Provides planning functionality to agents
    # @see PlanContext Tracks planning state across execution
    PlanningStep = Data.define(:model_input_messages, :model_output_message, :plan, :timing, :token_usage) do
      # Converts the planning step to a hash for serialization.
      #
      # @return [Hash] Hash with :plan, :timing, and :token_usage
      def to_h = { plan:, timing: timing&.to_h, token_usage: token_usage&.to_h }.compact

      # Converts planning step to chat messages for LLM context.
      #
      # @param summary_mode [Boolean] If true, omits input messages (output only)
      # @return [Array<ChatMessage>] Planning conversation messages in order
      def to_messages(summary_mode: false)
        (summary_mode ? [] : model_input_messages.to_a) + [model_output_message].compact
      end

      # Enables pattern matching with `in PlanningStep[plan:, timing:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = to_h
    end
  end
end
