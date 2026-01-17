module Smolagents
  module Types
    # Immutable token usage statistics from an LLM response.
    #
    # Tracks input and output tokens for billing, optimization, and cost analysis.
    # Supports accumulation across multiple steps via addition.
    #
    # @!attribute [r] input_tokens
    #   @return [Integer] Number of tokens in the input/prompt
    # @!attribute [r] output_tokens
    #   @return [Integer] Number of tokens in the output/completion
    #
    # @example Tracking token usage
    #   usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
    #   usage.total_tokens  # => 150
    #
    # @example Accumulating usage
    #   t1 = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
    #   t2 = Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
    #   total = t1 + t2
    #   total.total_tokens  # => 225
    #
    # @see ChatMessage#token_usage For usage in messages
    # @see ActionStep#token_usage For step-level tracking
    TokenUsage = Data.define(:input_tokens, :output_tokens) do
      # Creates a zero-initialized TokenUsage.
      #
      # @return [TokenUsage] Usage with 0 input and output tokens
      def self.zero = new(input_tokens: 0, output_tokens: 0)

      # Adds two token usage objects together.
      #
      # @param other [TokenUsage] Another usage to add
      # @return [TokenUsage] New usage with summed tokens
      def +(other)
        self.class.new(input_tokens: input_tokens + other.input_tokens,
                       output_tokens: output_tokens + other.output_tokens)
      end

      # Calculates total token count (input + output).
      #
      # @return [Integer] Sum of input and output tokens
      def total_tokens = input_tokens + output_tokens

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :input_tokens, :output_tokens, :total_tokens
      def to_h = { input_tokens:, output_tokens:, total_tokens: }

      # Enables pattern matching with `in TokenUsage[input_tokens:, output_tokens:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = to_h
    end
  end
end
