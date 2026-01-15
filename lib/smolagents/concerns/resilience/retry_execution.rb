module Smolagents
  module Concerns
    # Retry execution logic for model reliability.
    #
    # Provides methods to attempt model generation with retries
    # and emit appropriate events on failure.
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
        state = { attempt: starting_attempt, last_error: nil }
        policy.max_attempts.times do |retry_num|
          state[:attempt] += 1
          result = attempt_generate(model, messages, **)
          return result.merge(attempt: state[:attempt]) if result[:success]

          handle_retry_failure(model, result[:error], state, retry_num, policy)
        end
        { success: false, error: state[:last_error] || AgentError.new("Max retries exceeded"),
          attempt: state[:attempt] }
      end

      private

      def handle_retry_failure(model, error, state, retry_num, policy)
        state[:last_error] = error
        notify_error(error, state[:attempt], model)
        return if retry_num == policy.max_attempts - 1

        notify_retry(model, error, state[:attempt], policy.max_attempts, policy.backoff_for(retry_num))
      end

      def attempt_generate(model, messages, **)
        response = model == self ? generate_without_reliability(messages, **) : model.generate(messages, **)
        { success: true, response: }
      rescue *RetryPolicy.default.retryable_errors => e
        { success: false, error: e }
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
