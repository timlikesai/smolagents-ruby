module Smolagents
  module Concerns
    # Retry with backoff for tool execution.
    #
    # Provides retry logic specifically for tool calls that may encounter
    # rate limits or temporary service unavailability. Uses exponential
    # backoff to avoid overwhelming services.
    #
    # @example Basic usage
    #   include ToolRetry
    #
    #   result = with_tool_retry do
    #     http_tool.call(query: "search term")
    #   end
    #
    # @example Custom policy
    #   result = with_tool_retry(policy: custom_policy) do
    #     http_tool.call(query: "search term")
    #   end
    #
    # @see RetryPolicy For backoff configuration
    module ToolRetry
      # Default retry policy for tool calls.
      #
      # More aggressive than model retries since tool calls are usually cheaper
      # and rate limits are common. Uses jitter to prevent thundering herd.
      #
      # @return [RetryPolicy] Default tool retry configuration
      def self.default_policy
        RetryPolicy.new(
          max_attempts: 3,
          base_interval: 2.0,
          max_interval: 30.0,
          backoff: :exponential,
          jitter: 0.5,
          retryable_errors: ErrorClassification::RETRIABLE_ERRORS
        )
      end

      # Execute a block with retry and exponential backoff.
      #
      # Catches retryable errors and retries after sleeping for the
      # calculated backoff interval. Emits events for retry attempts
      # if the agent has an event emitter.
      #
      # @param policy [RetryPolicy] Retry configuration (default: tool policy)
      # @yield Block containing tool call to retry
      # @return [Object] Result of the block
      # @raise [StandardError] Last error if all retries exhausted
      #
      # @example
      #   with_tool_retry do
      #     search_tool.call(query: "ruby")
      #   end
      # rubocop:disable Metrics/MethodLength, Smolagents/NoSleep -- retry loop requires sleep
      def with_tool_retry(policy: ToolRetry.default_policy)
        attempt = 0
        last_error = nil

        loop do
          attempt += 1
          begin
            return yield
          rescue StandardError => e
            last_error = e
            # Use policy's retriable? method for smart error classification
            raise e unless policy.retriable?(e)
            raise e if attempt >= policy.max_attempts

            backoff_seconds = calculate_backoff(policy, attempt, e)
            emit_retry_event(attempt, policy.max_attempts, backoff_seconds, e)
            sleep(backoff_seconds)
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Smolagents/NoSleep

      private

      def calculate_backoff(policy, attempt, error)
        # Use retry-after header if available (for rate limits)
        if error.respond_to?(:retry_after) && error.retry_after
          [error.retry_after, policy.max_interval].min
        else
          policy.backoff_for(attempt - 1)
        end
      end

      def emit_retry_event(attempt, max_attempts, backoff_seconds, error)
        return unless respond_to?(:emit_event, true)

        emit_event(Events::ToolRetrying.create(
                     attempt:,
                     max_attempts:,
                     backoff_seconds:,
                     error_message: error.message
                   ))
      rescue NameError
        # ToolRetrying event not defined - skip
      end
    end
  end
end
