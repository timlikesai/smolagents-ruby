# frozen_string_literal: true

module Smolagents
  # Message roles for chat interactions.
  # These constants define the different types of messages in a conversation.
  module MessageRole
    # System message role - for system prompts and instructions
    SYSTEM = :system

    # User message role - for user inputs
    USER = :user

    # Assistant message role - for model outputs
    ASSISTANT = :assistant

    # Tool call message role - for tool invocations
    TOOL_CALL = :tool_call

    # Tool response message role - for tool results
    TOOL_RESPONSE = :tool_response

    # @return [Array<Symbol>] all valid message roles
    def self.all
      [SYSTEM, USER, ASSISTANT, TOOL_CALL, TOOL_RESPONSE]
    end

    # Check if a role is valid.
    # @param role [Symbol] the role to check
    # @return [Boolean] true if valid
    def self.valid?(role)
      all.include?(role)
    end
  end
end
