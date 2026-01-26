module Smolagents
  module Concerns
    # Retry execution logic for model reliability.
    #
    # Provides methods to attempt model generation with retries
    # and emit appropriate events on failure. Delegates to
    # {BaseRetryHandler} for core retry logic.
    #
    # @see BaseRetryHandler For the underlying retry implementation
    module RetryExecution
      # Try a model with retry logic.
      #
      # @param model [Model] Model to try
      # @param messages [Array] Messages to send
      # @param policy [RetryPolicy] Retry policy to use
      # @param starting_attempt [Integer] Current attempt number
      # @param kwargs [Hash] Additional arguments
      # @return [Hash] Result hash with :success, :response/:error, :attempt
      def try_model_with_retry(model, messages, policy, starting_attempt, **)
        # Track last failed attempt so we can compute final attempt number on success
        state = { last_failed_attempt: starting_attempt, model: }

        handler = build_model_retry_handler(policy, state)
        response = handler.execute { perform_generate(model, messages, **) }
        # Success happens one attempt after the last failure (or attempt 1 if no failures)
        final_attempt = state[:last_failed_attempt] + 1
        { success: true, response:, attempt: final_attempt }
      rescue StandardError => e
        { success: false, error: e, attempt: state[:last_failed_attempt] + 1 }
      end

      private

      def build_model_retry_handler(policy, state)
        # Use a method call for delay so tests can stub it
        delay_handler = ->(seconds) { retry_delay(seconds) }
        BaseRetryHandler.new(
          policy:,
          on_delay: delay_handler,
          on_retry: ->(info) { handle_model_retry(state[:model], state, info) },
          error_classifier: ->(e) { model_retriable_error?(e) }
        )
      end

      # Sleep before retry. Override or stub in tests to skip delays.
      # @param seconds [Float] Duration to sleep
      def retry_delay(seconds) = sleep(seconds) # rubocop:disable Smolagents/NoSleep -- retry backoff

      def handle_model_retry(model, state, info)
        # on_retry is called with the attempt that just failed
        state[:last_failed_attempt] = info[:attempt]
        notify_error(info[:error], info[:attempt], model)
        notify_retry(model, info[:error], info[:attempt], info[:max_attempts], info[:backoff_seconds])
      end

      def model_retriable_error?(error) = Types::RetryPolicy.default.retriable?(error)

      def perform_generate(model, messages, **)
        model == self ? generate_without_reliability(messages, **) : model.generate(messages, **)
      end

      def generate_without_reliability(messages, **)
        unless respond_to?(:original_generate, true)
          raise NotImplementedError,
                "Include ModelReliability after defining generate, or alias original_generate"
        end
        original_generate(messages, **)
      end
    end
  end
end
