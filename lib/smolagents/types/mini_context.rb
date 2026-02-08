# Minimal context for focused LLM calls.
#
# MiniContext provides a lightweight, budget-constrained context for quick
# LLM validation calls such as "Does this answer the question?" or simple
# extraction tasks. It tracks token estimates and prevents budget overflow.
#
# @example Basic usage
#   context = Types::MiniContext.empty(budget: 500, purpose: :validation)
#   context = context.add_message(ChatMessage.user("Yes or no?"))
#   context.headroom        #=> 494
#   context.to_messages     #=> [ChatMessage]
#
# @example Budget checking
#   context.can_fit?(100)   #=> true
#   context.over_budget?    #=> false
module Smolagents
  module Types
    MiniContext = Data.define(
      :messages,          # Array[ChatMessage]
      :budget,            # Integer - max tokens
      :estimated_tokens,  # Integer - current estimate
      :purpose            # Symbol - :validation, :extraction, :classification
    ) do
      CHARS_PER_TOKEN = 4

      # Creates an empty context with the given budget and purpose.
      # @param budget [Integer] Maximum token budget (default: 500)
      # @param purpose [Symbol] Context purpose (default: :validation)
      # @return [MiniContext]
      def self.empty(budget: 500, purpose: :validation)
        new(messages: [], budget:, estimated_tokens: 0, purpose:)
      end

      # Returns remaining budget.
      # @return [Integer] Tokens remaining (non-negative)
      def headroom = [budget - estimated_tokens, 0].max

      # Checks if estimated tokens exceed budget.
      # @return [Boolean]
      def over_budget? = estimated_tokens > budget

      # Checks if the given tokens can fit within remaining budget.
      # @param tokens [Integer] Number of tokens to check
      # @return [Boolean]
      def can_fit?(tokens) = tokens <= headroom

      # Adds a message to the context, returning a new context.
      # @param message [ChatMessage] Message to add
      # @param tokens [Integer, nil] Override token estimate
      # @return [MiniContext] New context with message added
      def add_message(message, tokens: nil)
        tokens ||= estimate_tokens(message)
        with(
          messages: [*messages, message].freeze,
          estimated_tokens: estimated_tokens + tokens
        )
      end

      # Returns messages array for LLM consumption.
      # @return [Array<ChatMessage>]
      def to_messages = messages

      private

      def estimate_tokens(message)
        (message.content.to_s.length / CHARS_PER_TOKEN.to_f).ceil
      end
    end
  end
end
