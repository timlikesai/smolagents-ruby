module Smolagents
  module Types
    # Constants for message roles in LLM conversations.
    #
    # MessageRole defines the valid roles that messages can have in a
    # conversation with an LLM. Each role indicates who sent the message
    # or what type of message it is.
    #
    # @example Checking valid roles
    #   Types::MessageRole.valid?(:user)  # => true
    #   Types::MessageRole.valid?(:unknown)  # => false
    #
    # @see ChatMessage Uses these roles for message categorization
    module MessageRole
      SYSTEM = :system

      USER = :user

      ASSISTANT = :assistant

      TOOL_CALL = :tool_call

      TOOL_RESPONSE = :tool_response

      def self.all
        [SYSTEM, USER, ASSISTANT, TOOL_CALL, TOOL_RESPONSE]
      end

      def self.valid?(role)
        all.include?(role)
      end
    end
  end
end
