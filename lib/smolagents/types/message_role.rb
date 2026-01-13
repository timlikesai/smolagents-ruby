module Smolagents
  module Types
    # Constants for message roles in LLM conversations.
    #
    # Defines the valid roles that messages can have in a conversation with
    # an LLM. Each role indicates who sent the message or what type of message
    # it is. Used throughout the system for message classification and handling.
    #
    # @example Checking valid roles
    #   Types::MessageRole.valid?(:user)  # => true
    #   Types::MessageRole.valid?(:unknown)  # => false
    #
    # @example Creating messages with roles
    #   ChatMessage.system("You are helpful")     # SYSTEM
    #   ChatMessage.user("Hello")                 # USER
    #   ChatMessage.assistant("Hi there")         # ASSISTANT
    #   ChatMessage.tool_call([...])              # TOOL_CALL
    #   ChatMessage.tool_response("Success")      # TOOL_RESPONSE
    #
    # @see ChatMessage Uses these roles for message categorization
    # @see ActionStep For steps with role-labeled messages
    module MessageRole
      # System prompt defining agent behavior and constraints.
      SYSTEM = :system

      # User message or task request.
      USER = :user

      # Assistant (LLM) response or action.
      ASSISTANT = :assistant

      # Tool call message (function calling format).
      TOOL_CALL = :tool_call

      # Tool response (execution result).
      TOOL_RESPONSE = :tool_response

      # Returns array of all valid message roles.
      #
      # @return [Array<Symbol>] All valid role constants
      # @example
      #   MessageRole.all  # => [:system, :user, :assistant, :tool_call, :tool_response]
      def self.all
        [SYSTEM, USER, ASSISTANT, TOOL_CALL, TOOL_RESPONSE]
      end

      # Validates if a role is in the allowed set.
      #
      # @param role [Symbol] Role to check
      # @return [Boolean] True if role is valid
      # @example
      #   MessageRole.valid?(:user)  # => true
      #   MessageRole.valid?(:invalid)  # => false
      def self.valid?(role)
        all.include?(role)
      end
    end
  end
end
