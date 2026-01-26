module Smolagents
  module Types
    # Immutable step containing the system prompt.
    #
    # SystemPromptStep wraps the system prompt and provides conversion
    # to message format. Always appears first in memory. Establishes the
    # agent's role, capabilities, and behavioral constraints.
    #
    # @example Creating a system prompt step
    #   step = Types::SystemPromptStep.new(
    #     system_prompt: "You are a helpful Ruby assistant..."
    #   )
    #
    # @see AgentMemory#system_prompt Stores the system prompt step
    # @see Agents System prompts define agent behavior
    SystemPromptStep = Data.define(:system_prompt) do
      # Converts the system prompt step to a hash for serialization.
      #
      # @return [Hash] Hash with :system_prompt key
      def to_h = { system_prompt: }

      # Converts system prompt step to chat messages for LLM context.
      #
      # @param _opts [Hash] Options (ignored for system prompt steps)
      # @return [Array<ChatMessage>] Single system message
      def to_messages(**_opts) = [ChatMessage.system(system_prompt)]

      # Enables pattern matching with `in SystemPromptStep[system_prompt:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = to_h
    end
  end
end
