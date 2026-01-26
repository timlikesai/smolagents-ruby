module Smolagents
  module Types
    # Immutable step marking task completion with final output.
    #
    # FinalAnswerStep captures the agent's final answer. It does not
    # contribute to messages since the answer is returned directly to the user.
    # This step terminates the ReAct loop and triggers finalization.
    #
    # @example Creating a final answer step
    #   step = Types::FinalAnswerStep.new(output: "The answer is 42")
    #
    # @see FinalAnswerTool Creates this step when called
    # @see Agents#run Returns this as the terminal step
    FinalAnswerStep = Data.define(:output) do
      # Converts the final answer step to a hash for serialization.
      #
      # @return [Hash] Hash with :output key containing the final answer
      def to_h = { output: }

      # Converts final answer step to chat messages for LLM context.
      #
      # Returns empty array because final answers are returned to the user,
      # not fed back to the LLM.
      #
      # @param _opts [Hash] Options (ignored for final answer steps)
      # @return [Array] Empty array (final answer not added to context)
      def to_messages(**_opts) = []

      # Enables pattern matching with `in FinalAnswerStep[output:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = to_h
    end
  end
end
