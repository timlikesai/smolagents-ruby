module Smolagents
  module Types
    # Metrics from compression operations.
    #
    # Tracks cumulative statistics about context compression over the lifetime
    # of an agent run. All fields are immutable; use record_compression to
    # create updated instances.
    #
    # @example Tracking compression
    #   metrics = CompressionMetrics.empty
    #   metrics = metrics.record_compression(steps: 5, tokens_saved: 1200)
    #   metrics.compressions_total  # => 1
    #   metrics.tokens_saved        # => 1200
    #
    # @see Concerns::Compression::Strategy Strategy interface
    CompressionMetrics = Data.define(
      :compressions_total,
      :steps_compressed,
      :tokens_saved,
      :last_compression_at
    ) do
      # Creates empty metrics with zero values.
      #
      # @return [CompressionMetrics] Fresh metrics instance
      def self.empty
        new(
          compressions_total: 0,
          steps_compressed: 0,
          tokens_saved: 0,
          last_compression_at: nil
        )
      end

      # Records a compression operation.
      #
      # @param steps [Integer] Number of steps compressed
      # @param tokens_saved [Integer] Tokens freed by compression
      # @return [CompressionMetrics] New metrics with updated values
      def record_compression(steps:, tokens_saved:)
        with(
          compressions_total: compressions_total + 1,
          steps_compressed: steps_compressed + steps,
          tokens_saved: self.tokens_saved + tokens_saved,
          last_compression_at: Time.now
        )
      end

      # Checks if any compression has occurred.
      #
      # @return [Boolean] True if at least one compression recorded
      def any? = compressions_total.positive?
    end
  end
end
