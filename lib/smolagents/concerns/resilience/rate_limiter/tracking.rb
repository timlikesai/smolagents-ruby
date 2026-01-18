module Smolagents
  module Concerns
    module RateLimiter
      # Request timing and rate tracking.
      module Tracking
        # @api private
        def self.included(base)
          base.attr_reader :request_count
        end

        # Check if a request is allowed without raising.
        # @return [Boolean] true if request can proceed
        def rate_limit_ok?
          return true unless @rate_limit

          elapsed = Time.now.to_f - @last_request_time
          elapsed >= @min_interval
        end

        # Get time until next request is allowed.
        # @return [Float] Seconds to wait (0.0 if ready now)
        def retry_after
          return 0.0 unless @rate_limit

          remaining = @min_interval - elapsed_since_last
          remaining.positive? ? remaining : 0.0
        end

        # Calculate time until next allowed request.
        # @return [Float] Seconds to wait (minimum 0)
        def time_until_allowed
          [@min_interval - elapsed_since_last, 0].max
        end

        # Mark that a request was made (for manual tracking).
        # @return [void]
        def mark_request!
          @last_request_time = Time.now.to_f
          @request_count = (@request_count || 0) + 1
        end

        # Get tool name for rate limit messages.
        # @return [String] Tool name or class name
        def rate_limit_tool_name
          respond_to?(:name) ? name : self.class.name
        end

        private

        def elapsed_since_last
          Time.now.to_f - @last_request_time
        end
      end
    end
  end
end
