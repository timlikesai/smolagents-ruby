module Smolagents
  module Concerns
    module Monitorable
      # Token usage tracking and accumulation.
      #
      # Tracks cumulative token usage across operations.
      # Logs usage deltas via logger when available.
      #
      # @example Tracking tokens
      #   track_tokens(TokenUsage.new(input_tokens: 100, output_tokens: 50))
      #   track_tokens(TokenUsage.new(input_tokens: 50, output_tokens: 25))
      #   total_token_usage  # => TokenUsage(150, 75)
      module TokenTracking
        # Track cumulative token usage.
        #
        # Adds tokens to running total and logs via logger.
        #
        # @param usage [TokenUsage] Token usage from current operation
        # @return [TokenUsage] Updated total token usage
        def track_tokens(usage)
          @total_tokens = total_token_usage + usage
          log_token_delta(usage, @total_tokens)
        end

        # Get total token usage since reset.
        #
        # @return [TokenUsage] Cumulative token usage
        def total_token_usage = @total_tokens || TokenUsage.zero

        # Reset token tracking state.
        #
        # @return [TokenUsage] Zero usage
        def reset_tokens = @total_tokens = TokenUsage.zero

        private

        # Log token usage delta and totals.
        #
        # @param delta [TokenUsage] Delta tokens just added
        # @param total [TokenUsage] New total
        # @api private
        def log_token_delta(delta, total)
          logger&.debug(
            "Tokens: +#{delta.input_tokens}/+#{delta.output_tokens} " \
            "(#{total.input_tokens}/#{total.output_tokens})"
          )
        end
      end
    end
  end
end
