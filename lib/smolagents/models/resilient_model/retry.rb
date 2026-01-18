module Smolagents
  module Models
    module ResilientModelConcerns
      # Retry logic for resilient model generation.
      # @example resilient.with_retry(max_attempts: 5, backoff: :exponential)
      module Retry
        # Configure retry behavior.
        # @param max_attempts [Integer, nil] Maximum retry attempts
        # @param base_interval [Float, nil] Initial backoff interval
        # @param max_interval [Float, nil] Maximum backoff interval
        # @param backoff [Symbol, nil] Backoff strategy (:constant, :linear, :exponential)
        # @param jitter [Float, nil] Jitter factor (0.0-1.0)
        # @param on [Array<Class>, nil] Retryable error classes
        # @return [self] For chaining
        def with_retry(**options)
          @retry_policy = merge_retry_options(options)
          self
        end

        private

        # Maps option keys to RetryPolicy attributes.
        RETRY_OPTION_KEYS = { on: :retryable_errors }.freeze

        def merge_retry_options(options)
          base = @retry_policy || Concerns::RetryPolicy.default
          normalized = options.compact.transform_keys { |k| RETRY_OPTION_KEYS.fetch(k, k) }
          Concerns::RetryPolicy.new(**base.to_h, **normalized)
        end

        # @param model [Model] Model to get policy for
        # @return [Concerns::RetryPolicy]
        def model_retry_policy(model)
          return @retry_policy if model == base_model && @retry_policy
          return model.retry_policy if model.respond_to?(:retry_policy, true) && model.retry_policy

          Concerns::RetryPolicy.default
        end

        # @return [Hash] Result with :success, :response/:error, :attempt
        def try_model_with_retry(model, messages, policy, starting_attempt, **)
          state = { attempt: starting_attempt, last_error: nil }
          policy.max_attempts.times do |retry_num|
            state[:attempt] += 1
            result = attempt_generate(model, messages, **)
            return result.merge(attempt: state[:attempt]) if result[:success]

            handle_retry_failure(model, result[:error], state, retry_num, policy)
          end
          { success: false,
            error: state[:last_error] || AgentError.new("Max retries exceeded"),
            attempt: state[:attempt] }
        end

        def handle_retry_failure(model, error, state, retry_num, policy)
          state[:last_error] = error
          notify_error(error, state[:attempt], model)
          return if retry_num == policy.max_attempts - 1

          notify_retry(model, error, state[:attempt], policy.max_attempts, policy.backoff_for(retry_num))
        end

        # @return [Hash] Result with :success and :response or :error
        def attempt_generate(model, messages, **)
          response = if model == base_model
                       base_model.generate(messages, **)
                     elsif model.is_a?(ResilientModel)
                       model.base_model.generate(messages, **)
                     else
                       model.generate(messages, **)
                     end
          { success: true, response: }
        rescue *Concerns::RetryPolicy.default.retryable_errors => e
          { success: false, error: e }
        end
      end
    end
  end
end
