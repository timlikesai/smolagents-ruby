module Smolagents
  module Types
    # Configuration for context compression.
    #
    # Controls when and how memory is compressed to fit within token budgets.
    # Supports multiple strategies: model-based summarization, keyword extraction,
    # or disabled (none).
    #
    # == Options
    #
    # - +:strategy+ - Compression approach (:model_based, :keyword, :none)
    # - +:threshold+ - Token usage fraction (0.0-1.0) to trigger compression
    # - +:preserve_recent+ - Number of recent steps to keep uncompressed
    # - +:max_summary_tokens+ - Maximum tokens for summary output
    #
    # @example Default configuration
    #   config = CompressionConfig.default
    #   config.strategy           # => :model_based
    #   config.threshold          # => 0.75
    #   config.enabled?           # => true
    #
    # @example Disabled compression
    #   config = CompressionConfig.disabled
    #   config.enabled?           # => false
    #
    # @see Concerns::Compression::Strategy Compression strategy interface
    CompressionConfig = Data.define(
      :strategy,
      :threshold,
      :preserve_recent,
      :max_summary_tokens
    ) do
      # Creates default compression configuration.
      #
      # @return [CompressionConfig] Config with model-based strategy at 75% threshold
      def self.default
        new(
          strategy: :model_based,
          threshold: 0.75,
          preserve_recent: 3,
          max_summary_tokens: 500
        )
      end

      # Creates disabled compression configuration.
      #
      # @return [CompressionConfig] Config that never compresses
      def self.disabled
        new(
          strategy: :none,
          threshold: 1.0,
          preserve_recent: 0,
          max_summary_tokens: 0
        )
      end

      # Checks if compression is enabled.
      #
      # @return [Boolean] True if strategy is not :none
      def enabled? = strategy != :none

      # Checks if using model-based compression.
      #
      # @return [Boolean] True if strategy is :model_based
      def model_based? = strategy == :model_based

      # Checks if using keyword compression.
      #
      # @return [Boolean] True if strategy is :keyword
      def keyword_based? = strategy == :keyword
    end
  end
end
