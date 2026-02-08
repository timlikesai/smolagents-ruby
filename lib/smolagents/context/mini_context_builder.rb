# Builder for focused, budget-constrained LLM contexts.
#
# Provides a fluent API for constructing small contexts for quick LLM calls
# like validation, extraction, or classification. Truncates to fit budget.
require_relative "../types/mini_context"
require_relative "../types/chat_message"

module Smolagents
  module Context
    class MiniContextBuilder
      CHARS_PER_TOKEN = 4
      RESPONSE_RESERVE = 100

      def initialize(budget: 500, purpose: :validation)
        @budget = budget
        @purpose = purpose
        @context = Types::MiniContext.empty(budget:, purpose:)
      end

      # Adds a system prompt (kept short, max 1/4 of budget).
      # @param content [String, nil] System prompt content
      # @return [self]
      def system(content)
        return self if content.nil? || content.empty?

        message = Types::ChatMessage.system(truncate_to_budget(content, @budget / 4))
        @context = @context.add_message(message)
        self
      end

      # Adds a user message (main content).
      # @param content [String] User message content
      # @return [self]
      def user(content)
        remaining = @context.headroom - RESPONSE_RESERVE
        message = Types::ChatMessage.user(truncate_to_budget(content, remaining))
        @context = @context.add_message(message)
        self
      end

      # Adds context from observation (truncated).
      # @param text [String] Observation text
      # @param max_tokens [Integer, nil] Maximum tokens for observation
      # @return [self]
      def observation(text, max_tokens: nil)
        max_tokens ||= @context.headroom / 2
        truncated = truncate_to_budget(text, max_tokens)
        user("Observation: #{truncated}")
      end

      # Adds a yes/no validation prompt.
      # @param question [String] The question to validate
      # @return [self]
      def yes_no_validation(question)
        user("#{question}\n\nRespond with only 'yes' or 'no'.")
      end

      # Adds an extraction prompt.
      # @param target [String] What to extract
      # @param from [String] Source text
      # @return [self]
      def extract(target, from:)
        remaining = @context.headroom - RESPONSE_RESERVE
        user("Extract #{target} from the following:\n\n#{truncate_to_budget(from, remaining)}")
      end

      # Builds the final MiniContext.
      # @return [Types::MiniContext] Frozen context
      def build = @context.freeze

      # Builds and returns messages array.
      # @return [Array<ChatMessage>]
      def to_messages = build.to_messages

      # Checks if more content can fit.
      # @param tokens [Integer] Number of tokens
      # @return [Boolean]
      def can_fit?(tokens) = @context.can_fit?(tokens)

      # Returns current estimated token count.
      # @return [Integer]
      def estimated_tokens = @context.estimated_tokens

      private

      def truncate_to_budget(content, max_tokens)
        max_chars = max_tokens * CHARS_PER_TOKEN
        content.to_s[0, max_chars] || ""
      end
    end
  end
end
