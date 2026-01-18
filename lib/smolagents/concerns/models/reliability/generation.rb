module Smolagents
  module Concerns
    module Reliability
      # Reliable generation with retry and failover.
      #
      # Provides the main reliable_generate method and health helpers.
      #
      # @example Generate with reliability
      #   response = model.reliable_generate(messages)
      module Generation
        # Generate with full reliability stack.
        #
        # Attempts generation with retry and fallback chain handling.
        # Use this instead of generate when reliability is configured.
        #
        # @param messages [Array<ChatMessage>] Messages to send
        # @param kwargs [Hash] Additional arguments passed to generate
        # @return [ChatMessage] Model response
        # @raise [AgentError] If all models fail after retries
        def reliable_generate(messages, **)
          state = { last_error: nil, attempt: 0 }
          result = try_chain(messages, state, **) do |model, next_model, msgs, st|
            try_model_in_chain(model, next_model, msgs, st, **)
          end
          return result if result

          raise state[:last_error] || AgentError.new("All models failed")
        end

        # Check if any model in the chain is healthy.
        # @return [Boolean] True if at least one model passes health check
        def any_healthy? = any_model_healthy?(model_chain)

        # Get the first healthy model in the chain.
        # @return [Model, nil] First healthy model or nil
        def first_healthy = first_healthy_model(model_chain)

        private

        def model_retry_policy(model)
          return @retry_policy if model == self && @retry_policy
          return model.send(:retry_policy) if model.respond_to?(:retry_policy, true) && model.send(:retry_policy)

          RetryPolicy.default
        end

        def try_model_in_chain(model, next_model, messages, state, **)
          return nil if skip_unhealthy?(model, next_model, state[:attempt])

          result = try_model_with_retry(model, messages, model_retry_policy(model), state[:attempt], **)
          return handle_success(model, result) if result&.dig(:success)

          state[:last_error] = result[:error]
          state[:attempt] = result[:attempt]
          notify_failover(model, next_model, state[:last_error], state[:attempt]) if next_model
          nil
        end

        def skip_unhealthy?(model, next_model, attempt)
          return false unless should_skip_unhealthy?(model)

          notify_failover(model, next_model, AgentError.new("Health check failed"), attempt)
          true
        end

        def handle_success(model, result)
          notify_recovery(model, result[:attempt]) if result[:attempt] > 1
          result[:response]
        end
      end
    end
  end
end
